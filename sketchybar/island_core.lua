-- Dynamic notch pill engine: animate bar geometry, never item y_offset inside
-- animate batches; sticky high-priority pills suppress lower expands.

local display = require "display"
local island_style = require "island_style"
local island_text = require "island_text"
local motion = require "motion"
local settings = require "settings"

local TRANSPARENT = 0x00ffffff

local BAR_H = settings.island.bar_height or settings.bar_height or 32
local IDLE_H = settings.island.idle_height or BAR_H
local EXPAND_H = settings.island.expand_height or 48
local SIZING = settings.island.sizing or {}
local F_EXPAND = settings.island.frames_expand or settings.motion.normal
local F_RETRACT = settings.island.frames_retract or settings.motion.normal

-- Higher = more important. Sticky expand only yields to equal/higher priority.
local PRIORITY = {
  siri = 90,
  window = 68,
  mic = 65,
  bluetooth = 52,
  layout = 40,
  appswitch = 10,
  default = 20,
}

local function y_idle(idx)
  return island_style.y_offset_idle(idx)
end

local function y_expand(idx)
  return island_style.y_offset_expand(idx)
end

-- Island follows the focused display; every sbar.bar carries `display`. Cache
-- focus so expand() does not shell yabai|jq on every toast.
local current_display = display.focused_index()
local cached_focus = current_display

local function display_width(idx)
  for _, d in ipairs(display.displays) do
    if d.index == idx and d.width then
      return d.width
    end
  end
  return display.main_width
end

-- Pill baseline: notch on built-in, small on external.
local function pill_base(idx)
  if idx == display.builtin_index and display.notch_width > 0 then
    return display.notch_width
  end
  return 160
end

local function idle_margin(idx)
  local dw = display_width(idx)
  local pw = pill_base(idx)
  return math.max(0, math.floor(dw / 2) - math.floor(pw / 2))
end

local NOTCH_W = pill_base(current_display)

-- Per-toast pill width from exact text metrics (see settings.island.sizing).
-- May pixel-refit item.left.text in place when the max width caps the wing.
local function pill_width(target, item, lpl, lpr, rpl, rpr)
  if item.width then
    return math.max(160, item.width)
  end
  local L = item.left
  local R = item.right
  local step = SIZING.width_step or 20
  local max_w = SIZING.max_width or 620
  local slack = SIZING.text_slack or 2
  local lsize = (L and type(L.font) == "table" and L.font.size) or 15
  local text_w = L and island_text.measure(L.text or "", lsize) or 0
  local r_box = R and (R.width or SIZING.right_lobe or 48) or 0

  if island_style.on_notched_builtin(target) then
    local eff_notch = display.notch_width + 2 * (SIZING.notch_fudge or 10)
    local l_wing = lpl + text_w + lpr + slack
    local r_wing = rpl + r_box + rpr
    local w = math.ceil((eff_notch + 2 * math.max(l_wing, r_wing)) / step) * step
    if w > max_w then
      w = max_w
      if L then
        -- Hard guarantee: text can never render under the physical cutout.
        local avail = (max_w - eff_notch) / 2 - lpl - lpr - slack
        L.text = island_text.fit(L.text or "", lsize, avail)
      end
    end
    return w
  end

  -- Notchless: halves cluster at the center; each half holds its content.
  local half = math.max(lpl + text_w + lpr, rpl + r_box + rpr)
  local w = math.ceil((2 * half + (SIZING.notchless_gap or 24)) / step) * step
  return math.max(SIZING.notchless_min or 160, math.min(w, max_w))
end

local function bar_props(extra)
  local style = island_style.bar()
  local props = {
    color = style.color,
    border_color = style.border_color,
    border_width = style.border_width,
    corner_radius = style.corner_radius,
  }
  if extra then
    for key, value in pairs(extra) do
      if value ~= nil then
        props[key] = value
      end
    end
  end
  return props
end

local function resolve_font(f)
  if type(f) == "string" then
    return f
  end
  f = f or {}
  local style = f.style or "Semibold"
  return {
    family = f.family or settings.font.family,
    style = settings.font.style_map[style] or style,
    size = f.size or 13,
  }
end

local function with_color(content, color)
  local t = {}
  for k, v in pairs(content) do
    t[k] = v
  end
  t.color = color
  return t
end

local island_sub = sbar.add("item", "island.sub", {
  position = "center",
  width = 0,
  updates = false,
  click_script = "sketchybar-island --trigger island_tap",
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    drawing = true,
    color = TRANSPARENT,
    string = "",
    width = 0,
    font = resolve_font { size = 12, style = "Regular" },
    padding_left = 0,
    padding_right = 0,
    align = "center",
  },
  background = { drawing = false },
})

-- Constant downward shift of the pill text (set once; never animated).
local TEXT_Y = settings.island.text_y_offset or 0

local island = sbar.add("item", "island.main", {
  position = "center",
  width = NOTCH_W,
  updates = true,
  y_offset = TEXT_Y,
  padding_left = 0,
  padding_right = 0,
  click_script = "sketchybar-island --trigger island_tap",
  icon = {
    drawing = true,
    color = TRANSPARENT,
    string = "",
    align = "center",
    font = resolve_font {},
    padding_left = 12,
    padding_right = 4,
  },
  label = {
    drawing = true,
    color = TRANSPARENT,
    string = "",
    align = "center",
    font = resolve_font {},
    width = NOTCH_W - 20,
    padding_left = 4,
    padding_right = 12,
  },
  background = { drawing = false },
})

local is_expanded = false
local retracting = false
local cur_priority = 0
local cur_sticky = false
local cur_kind = nil

-- Monotonic tokens cancel stale sbar.delay callbacks (dismiss / post-retract hide).
local dismiss_token = 0
local hide_token = 0

-- Last applied geometry. Animate batches only carry props whose value changes
-- (sketchybar interpolates constant props through truncated midpoints → jitter).
local cur_w = NOTCH_W
local cur_h = BAR_H
local cur_mg = idle_margin(current_display)

-- Last applied colors (same rule as geometry: animating a color to its current
-- value is a constant-prop batch entry — the old snap-then-animate double set
-- was a flicker source on morphs and fresh shows).
local cur_bar_color = island_style.bar().color
local cur_bar_border = island_style.bar().border_color
local cur_icon_color = TRANSPARENT
local cur_label_color = TRANSPARENT

-- Last applied bar y_offset (the vertical dismiss animates it; morphs that
-- arrive mid-dismiss must ride it back down inside the animate batch).
local cur_y = y_idle(current_display)

local M = {}
M.IDLE_H = IDLE_H
M.EXPAND_H = EXPAND_H
M.priority = PRIORITY

local function cancel_dismiss()
  dismiss_token = dismiss_token + 1
end

local function cancel_hide()
  hide_token = hide_token + 1
end

local function apply_idle_geometry(opts)
  opts = opts or {}
  local hide = opts.hidden ~= false
  local base = pill_base(current_display)
  local mg = idle_margin(current_display)
  local style = island_style.bar()
  cur_w, cur_h, cur_mg = base, BAR_H, mg
  cur_bar_color, cur_bar_border = style.color, style.border_color
  cur_icon_color, cur_label_color = TRANSPARENT, TRANSPARENT
  cur_y = y_idle(current_display)
  island_sub:set {
    y_offset = 0,
    label = { color = TRANSPARENT, string = "", width = 0, padding_left = 0, padding_right = 0 },
  }
  island:set {
    width = base,
    icon = {
      string = "",
      color = TRANSPARENT,
      align = "center",
      width = 0,
      padding_left = 12,
      padding_right = 4,
    },
    label = {
      string = "",
      color = TRANSPARENT,
      align = "center",
      width = base - 20,
      padding_left = 4,
      padding_right = 12,
    },
  }
  sbar.bar(bar_props {
    display = current_display,
    height = BAR_H,
    margin = mg,
    y_offset = y_idle(current_display),
    color = style.color,
    border_color = style.border_color,
    hidden = hide,
    -- Idle/hidden must not be topmost (covers top-bar space app icons).
    topmost = hide and "off" or "on",
  })
end

-- sbar.delay rides the animation tick: when macOS 26 wedges the CVDisplayLink
-- (lock/unlock — all sketchybar animations freeze system-wide), delays die
-- with it and pills would stay stuck on screen. sbar.exec callbacks are
-- process-exit driven and survive a wedge, so every timer runs both — the
-- `fired` flag plus the monotonic token keep the pair idempotent.
local function dual_timer(seconds, fn)
  local fired = false
  local function once()
    if fired then
      return
    end
    fired = true
    fn()
  end
  sbar.delay(seconds, once)
  sbar.exec("sleep " .. string.format("%.2f", seconds + 0.4), once)
end

local function schedule_dismiss(duration)
  cancel_dismiss()
  if not duration or duration <= 0 then
    return
  end
  local token = dismiss_token
  dual_timer(duration, function()
    if token ~= dismiss_token or not is_expanded then
      return
    end
    M.restore_idle()
  end)
end

local function schedule_hide(frames)
  cancel_hide()
  local token = hide_token
  local delay = math.max(0.3, (frames or motion.frames.normal) / 60 + 0.08)
  dual_timer(delay, function()
    if token ~= hide_token then
      return
    end
    retracting = false
    if not is_expanded then
      apply_idle_geometry { hidden = true }
      -- Belt: sketchybar sometimes drops topmost in a merged bar set.
      sbar.bar { hidden = true, topmost = "off" }
    end
  end)
end

local function resolve_priority(item)
  if item.priority then
    return item.priority
  end
  if item.kind and PRIORITY[item.kind] then
    return PRIORITY[item.kind]
  end
  return PRIORITY.default
end

local function expand_on(target, item)
  current_display = target
  cancel_hide()
  cancel_dismiss()

  local L = item.left
  local R = item.right
  local S = item.subtitle

  local lpl = L and (L.padding_left or 12) or 12
  local lpr = L and (L.padding_right or 4) or 4
  local rpl = R and (R.padding_left or 4) or 4
  local rpr = R and (R.padding_right or 12) or 12

  local w = pill_width(target, item, lpl, lpr, rpl, rpr)
  local h = item.height
  if not h or h == IDLE_H then
    h = EXPAND_H
  end
  local dw = display_width(target)
  local mg = math.max(0, math.floor(dw / 2) - math.floor(w / 2))

  local l_fixed = L and L.width or nil
  local r_fixed = R and R.width or nil
  local pad = lpl + lpr + rpl + rpr
  local inner = math.max(0, w - pad)
  local notched = island_style.on_notched_builtin(target)

  -- Notched built-in: left text in a wide box that fills the width (pushing the
  -- glyph into a fixed right lobe with only small paddings); widths in
  -- settings.lua keep the text clear of the notch. Notchless: equal halves.
  local l_width, r_width, l_align, r_align
  if L and R then
    if l_fixed and r_fixed then
      l_width, r_width = l_fixed, r_fixed
    elseif notched then
      r_width = r_fixed or 48
      l_width = math.max(0, inner - r_width)
    else
      l_width = math.floor(inner / 2)
      r_width = inner - l_width
    end
    if notched then
      l_align = (L and L.align) or "left"
      r_align = (R and R.align) or "center"
    else
      l_align = (L and L.align) or "right"
      r_align = (R and R.align) or "left"
    end
  elseif L then
    l_width = l_fixed or inner
    r_width = 0
    l_align = (L and L.align) or "left"
    r_align = "center"
  elseif R then
    l_width = 0
    r_width = r_fixed or (w - 20)
    l_align = "center"
    r_align = (R and R.align) or "center"
  else
    l_width = 0
    r_width = w - 20
    l_align = "center"
    r_align = "center"
  end

  local sfont = S and resolve_font(S.font or { size = 12, style = "Regular" }) or nil
  local sub_y = sfont and (TEXT_Y - (sfont.size + 16)) or 0

  local frames = item.frames or F_EXPAND
  local style = island_style.bar()
  local pill_color = item.color or style.color
  local pill_border = item.border_color or style.border_color

  local icon_color = L and (L.color or island_style.muted()) or TRANSPARENT
  local label_color = R and (R.color or island_style.text()) or TRANSPARENT
  local icon_content = {
    string = L and (L.text or "") or "",
    font = resolve_font(L and L.font or {}),
    width = l_width or 0,
    align = l_align,
    padding_left = lpl,
    padding_right = lpr,
  }
  local label_content = {
    string = R and (R.text or "") or "",
    font = resolve_font(R and R.font or {}),
    width = r_width or 0,
    align = r_align,
    padding_left = rpl,
    padding_right = rpr,
  }

  -- Same-kind update while open (e.g. app A→B): swap strings only, no re-seed.
  if is_expanded and not retracting and item.kind and item.kind == cur_kind and cur_w == w and cur_h == h then
    island:set {
      icon = with_color(icon_content, icon_color),
      label = with_color(label_content, label_color),
    }
    if S then
      island_sub:set {
        y_offset = sub_y,
        label = {
          color = S.color or island_style.muted(),
          string = S.text or "",
          width = w - lpl - rpr,
          font = sfont,
          align = S.align or "left",
          padding_left = lpl,
          padding_right = rpr,
        },
      }
    else
      island_sub:set {
        y_offset = 0,
        label = { color = TRANSPARENT, string = "", width = 0 },
      }
    end
    cur_icon_color, cur_label_color = icon_color, label_color
    cur_priority = resolve_priority(item)
    cur_sticky = item.sticky == true or (item.duration ~= nil and item.duration == 0)
    schedule_dismiss(item.duration)
    return
  end

  -- Fresh show: seed content (transparent) BEFORE unhiding so the first visible
  -- frame never shows stale strings/widths, then grow out of the notch strip.
  -- Mid-retract / size change: morph from current geometry.
  if not is_expanded and not retracting then
    local seed_mg = idle_margin(target)
    cur_w, cur_h, cur_mg = w, BAR_H, seed_mg
    island:set {
      width = w,
      icon = with_color(icon_content, TRANSPARENT),
      label = with_color(label_content, TRANSPARENT),
    }
    cur_icon_color, cur_label_color = TRANSPARENT, TRANSPARENT
    sbar.bar(bar_props {
      hidden = false,
      topmost = "on",
      display = target,
      height = BAR_H,
      margin = seed_mg,
      y_offset = y_expand(target),
      color = pill_color,
      border_color = pill_border,
    })
    cur_bar_color, cur_bar_border = pill_color, pill_border
    cur_y = y_expand(target)
  else
    -- y_offset deliberately NOT snapped here: mid-dismiss the pill sits partly
    -- above the edge and must slide back down inside the animate batch.
    sbar.bar {
      hidden = false,
      display = target,
    }
    -- Snap width with content: animating it mid-morph clips/drifts the glyph.
    -- Colors are NOT snapped here — the animate batch below carries them from
    -- whatever is on screen (mid-fade during a retract) to the new targets.
    island:set {
      width = w,
      icon = icon_content,
      label = label_content,
    }
  end

  -- Subtitle geometry is set instantly (item y_offset must not animate).
  if S then
    island_sub:set {
      y_offset = sub_y,
      label = {
        color = TRANSPARENT,
        string = S.text or "",
        width = w - lpl - rpr,
        font = sfont,
        align = S.align or "left",
        padding_left = lpl,
        padding_right = rpr,
      },
    }
  else
    island_sub:set {
      y_offset = 0,
      label = { color = TRANSPARENT, string = "", width = 0 },
    }
  end

  -- Fade content in / morph geometry. Every prop in the animate batch must be
  -- actually changing — constant-valued entries jitter (geometry) or double-set
  -- (colors), both visible as flicker.
  local bar_anim = {}
  if cur_h ~= h then
    bar_anim.height = h
  end
  if cur_mg ~= mg then
    bar_anim.margin = mg
  end
  if cur_y ~= y_expand(target) then
    bar_anim.y_offset = y_expand(target)
  end
  if next(bar_anim) then
    -- Bar color rides the geometry batch when it changes (morph from a
    -- mid-retract fade or a differently-tinted pill like siri).
    if pill_color ~= cur_bar_color then
      bar_anim.color = pill_color
    end
    if pill_border ~= cur_bar_border then
      bar_anim.border_color = pill_border
    end
  elseif pill_color ~= cur_bar_color or pill_border ~= cur_bar_border then
    -- No geometry change: snap the color outside animate. A color-only bar
    -- batch gets mangled by sketchybar (omitted margin zeroes → full-width).
    sbar.bar { color = pill_color, border_color = pill_border }
  end

  local island_anim = {}
  if icon_color ~= cur_icon_color then
    island_anim.icon = { color = icon_color }
  end
  if label_color ~= cur_label_color then
    island_anim.label = { color = label_color }
  end

  local needs_bar_anim = next(bar_anim) ~= nil
  local needs_island_anim = next(island_anim) ~= nil
  if needs_bar_anim or needs_island_anim or S then
    sbar.animate(motion.curve, frames, function()
      if needs_bar_anim then
        sbar.bar(bar_anim)
      end
      if needs_island_anim then
        island:set(island_anim)
      end
      if S then
        island_sub:set {
          label = { color = S.color or island_style.muted() },
        }
      end
    end)
  end

  cur_w, cur_h, cur_mg = w, h, mg
  cur_y = y_expand(target)
  cur_bar_color, cur_bar_border = pill_color, pill_border
  cur_icon_color, cur_label_color = icon_color, label_color
  is_expanded = true
  retracting = false
  cur_priority = resolve_priority(item)
  cur_kind = item.kind
  cur_sticky = item.sticky == true or (item.duration ~= nil and item.duration == 0)
  schedule_dismiss(item.duration)
end

function M.expand(item)
  item = item or {}
  local prio = resolve_priority(item)
  if is_expanded then
    -- Lower priority never clobbers a visible pill.
    if prio < cur_priority then
      return false
    end
    -- Sticky: equal priority only morphs same kind; higher still replaces.
    if cur_sticky and prio == cur_priority and item.kind ~= cur_kind then
      return false
    end
  end
  expand_on(cached_focus or current_display, item)
  return true
end

local function on_display_or_focus(env)
  -- Hotplug / arrangement change: re-probe notch + display widths before retarget.
  if env and env.SENDER == "display_change" and display.refresh then
    display.refresh()
  end
  local target = display.focused_index()
  cached_focus = target
  if target == current_display and not (env and env.SENDER == "display_change") then
    return
  end
  current_display = target
  if not is_expanded then
    apply_idle_geometry { hidden = true }
    return
  end
  local query = island:query()
  local w = tonumber(query and query.geometry and query.geometry.width) or pill_base(target)
  local dw = display_width(target)
  local mg = math.max(0, math.floor(dw / 2) - math.floor(w / 2))
  cur_mg = mg
  cur_y = y_expand(target)
  sbar.bar(bar_props { display = target, height = cur_h, margin = mg, y_offset = cur_y })
end

function M.restore_idle(opts)
  if not is_expanded then
    -- Still force idle geometry if we got stuck expanded visually.
    if not retracting then
      apply_idle_geometry { hidden = true }
    end
    return
  end
  opts = opts or {}
  is_expanded = false
  retracting = true
  cur_priority = 0
  cur_sticky = false
  cur_kind = nil
  cancel_dismiss()

  local frames = opts.frames or F_RETRACT

  -- Subtitle position must be snapped (item y_offset must never animate).
  island_sub:set {
    y_offset = 0,
    label = { color = TRANSPARENT, string = "", width = 0, padding_left = 0, padding_right = 0 },
  }

  -- Keep the pill visible + topmost through the whole dismiss.
  sbar.bar { display = current_display, hidden = false, topmost = "on" }

  -- Vertical dismiss: slide the pill straight up behind the screen edge,
  -- SOLID — no fade. Fading made the pill translucent mid-slide (visibly not
  -- the notch's black, read as flicker); a solid notch-black pill tucking into
  -- the edge is the smooth path. y_offset → -(height+1) puts the whole bar
  -- above y=0, so the deferred hide + idle snap happen fully off-screen.
  -- y_offset is the ONLY animated prop (a changing geometry prop, so the
  -- batch is not color-only); width/margin/height/colors stay constant and
  -- stay OUT of the batch (constant props jitter). Trackers are NOT reset
  -- here: the bar physically keeps the expanded geometry/colors until
  -- apply_idle_geometry snaps idle after the hide, and a morph arriving
  -- mid-dismiss must see the real values (it rides y_offset back down and
  -- skips the untouched colors).
  local slide_y = -(cur_h + 1)
  sbar.animate(motion.curve, frames, function()
    sbar.bar { y_offset = slide_y }
  end)
  cur_y = slide_y

  -- Fully hide + re-assert idle geometry (clears strings + item width) once
  -- the pill is off-screen.
  schedule_hide(frames)
end

-- Lock screen: drop any pill and force hidden idle geometry.
function M.force_hide()
  cancel_dismiss()
  cancel_hide()
  is_expanded = false
  retracting = false
  cur_priority = 0
  cur_sticky = false
  cur_kind = nil
  apply_idle_geometry { hidden = true }
end

-- Unlock: keep bar hidden; next expand seeds from idle.
function M.on_unlock()
  if not is_expanded then
    apply_idle_geometry { hidden = true }
  end
end

island:subscribe("island_tap", function()
  M.restore_idle()
end)

local focus_watcher = sbar.add("item", "island.focus", {
  drawing = false,
  updates = true,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

focus_watcher:subscribe({ "display_change", "window_focus" }, on_display_or_focus)

-- Mission Control (from yabai): the pill is topmost while expanded and would
-- float over the space overview — drop it.
focus_watcher:subscribe("island_hide", function()
  M.force_hide()
end)

function M.refresh_theme()
  if is_expanded then
    -- Recolor only; the expanded geometry stays as-is.
    sbar.bar(bar_props())
    return
  end
  cur_y = y_idle(current_display)
  sbar.bar(bar_props {
    display = current_display,
    margin = idle_margin(current_display),
    y_offset = cur_y,
    hidden = true,
  })
end

-- Ensure clean idle geometry at load (recovers stuck full-width from prior session).
apply_idle_geometry { hidden = true }

return M
