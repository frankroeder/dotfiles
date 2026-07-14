-- Dynamic notch pill engine: animate bar geometry, never item y_offset inside
-- animate batches; sticky high-priority pills suppress lower expands.

local display = require "display"
local island_style = require "island_style"
local motion = require "motion"
local settings = require "settings"

local TRANSPARENT = 0x00ffffff

local BAR_H = settings.island.bar_height or 45
local IDLE_H = settings.island.idle_height or 51
local EXPAND_H = settings.island.expand_height or 125

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

local function effective_width(_idx, w)
  return math.max(160, w or 160)
end

local function idle_margin(idx)
  local dw = display_width(idx)
  local pw = pill_base(idx)
  return math.max(0, math.floor(dw / 2) - math.floor(pw / 2))
end

local NOTCH_W = pill_base(current_display)

local function bar_props(extra, idx)
  local style = island_style.bar(idx or current_display)
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
-- kind -> unix time until which expands of that kind are suppressed (anti-stack).
local suppress_until = {}

-- Last applied geometry. Animate batches only carry props whose value changes
-- (sketchybar interpolates constant props through truncated midpoints → jitter).
local cur_w = NOTCH_W
local cur_h = BAR_H
local cur_mg = idle_margin(current_display)

local M = {}
M.BAR_H = BAR_H
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
  local style = island_style.bar(current_display)
  cur_w, cur_h, cur_mg = base, BAR_H, mg
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
  sbar.bar(bar_props({
    display = current_display,
    height = BAR_H,
    margin = mg,
    y_offset = y_idle(current_display),
    color = style.color,
    border_color = style.border_color,
    hidden = hide,
    -- Idle/hidden must not be topmost (covers top-bar space app icons).
    topmost = hide and "off" or "on",
  }, current_display))
end

local function schedule_dismiss(duration)
  cancel_dismiss()
  if not duration or duration <= 0 then
    return
  end
  local token = dismiss_token
  sbar.delay(duration, function()
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
  sbar.delay(delay, function()
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

  local w = effective_width(target, item.width or pill_base(target))
  local h = item.height or IDLE_H
  local dw = display_width(target)
  local mg = math.max(0, math.floor(dw / 2) - math.floor(w / 2))

  local L = item.left
  local R = item.right
  local S = item.subtitle

  local lpl = L and (L.padding_left or 12) or 12
  local lpr = L and (L.padding_right or 4) or 4
  local rpl = R and (R.padding_left or 4) or 4
  local rpr = R and (R.padding_right or 12) or 12

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

  local frames = item.frames or motion.frames.normal
  local style = island_style.bar(target)
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
    cur_priority = resolve_priority(item)
    cur_sticky = item.sticky == true or (item.duration ~= nil and item.duration == 0)
    schedule_dismiss(item.duration)
    return
  end

  -- Fresh show: unhide already at target size (no notch-seed flash).
  -- Mid-retract / size change: morph from current geometry.
  if not is_expanded and not retracting then
    cur_w, cur_h, cur_mg = w, h, mg
    sbar.bar(bar_props({
      hidden = false,
      topmost = "on",
      display = target,
      height = h,
      margin = mg,
      y_offset = y_expand(target),
      color = pill_color,
      border_color = pill_border,
    }, target))
    island:set {
      width = w,
      icon = with_color(icon_content, TRANSPARENT),
      label = with_color(label_content, TRANSPARENT),
    }
  else
    sbar.bar {
      hidden = false,
      display = target,
      y_offset = y_expand(target),
    }
    -- Snap width with content: animating it mid-morph clips/drifts the glyph.
    island:set {
      width = w,
      icon = with_color(icon_content, icon_color),
      label = with_color(label_content, label_color),
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

  -- Fade content in; only animate geometry when it actually changes (morph).
  local bar_anim = {}
  if cur_h ~= h then
    bar_anim.height = h
  end
  if cur_mg ~= mg then
    bar_anim.margin = mg
  end
  if not is_expanded and not retracting then
    bar_anim.color = pill_color
    bar_anim.border_color = pill_border
  else
    if pill_color then
      bar_anim.color = pill_color
    end
    if pill_border then
      bar_anim.border_color = pill_border
    end
  end
  local island_anim = {
    icon = { color = icon_color },
    label = { color = label_color },
  }

  local needs_bar_anim = next(bar_anim) ~= nil
  sbar.animate(motion.curve, frames, function()
    if needs_bar_anim then
      sbar.bar(bar_anim)
    end
    island:set(island_anim)
    if S then
      island_sub:set {
        label = { color = S.color or island_style.muted() },
      }
    end
  end)

  cur_w, cur_h, cur_mg = w, h, mg
  is_expanded = true
  retracting = false
  cur_priority = resolve_priority(item)
  cur_kind = item.kind
  cur_sticky = item.sticky == true or (item.duration ~= nil and item.duration == 0)
  schedule_dismiss(item.duration)
end

function M.suppress_kind(kind, seconds)
  if not kind then
    return
  end
  suppress_until[kind] = os.time() + (seconds or 1)
end

function M.expand(item)
  item = item or {}
  local kind = item.kind
  local hold = kind and suppress_until[kind]
  if hold and os.time() < hold then
    return false
  end
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
  sbar.bar(bar_props({ display = target, height = cur_h, margin = mg, y_offset = y_expand(target) }, target))
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

  local base = pill_base(current_display)
  local frames = opts.frames or motion.frames.normal
  local style = island_style.bar(current_display)
  local mg = idle_margin(current_display)

  -- Snap idle geometry OUTSIDE animate. Sketchybar animate batches that only
  -- carry color can zero omitted margin/width (full-display stretch).
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
  sbar.bar(bar_props({
    display = current_display,
    height = BAR_H,
    margin = mg,
    y_offset = y_idle(current_display),
    hidden = false,
    topmost = "on",
  }, current_display))

  -- Color fade only (no geometry in the animate batch).
  sbar.animate(motion.curve, frames, function()
    sbar.bar { color = style.color, border_color = style.border_color }
  end)
  cur_w, cur_h, cur_mg = base, BAR_H, mg

  -- Fully hide + re-assert idle geometry once fade finishes.
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

-- Clear sticky of a given kind (or any sticky) then optionally stay idle.
function M.clear_sticky(kind)
  if not is_expanded or not cur_sticky then
    return false
  end
  if kind and cur_kind ~= kind then
    return false
  end
  M.restore_idle()
  return true
end

function M.is_expanded()
  return is_expanded
end

function M.current_priority()
  return cur_priority
end

function M.current_kind()
  return cur_kind
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

function M.current_display()
  return current_display
end

function M.refresh_theme()
  if is_expanded then
    -- Recolor only; the expanded geometry stays as-is.
    sbar.bar(bar_props(nil, current_display))
    return
  end
  sbar.bar(bar_props({
    display = current_display,
    margin = idle_margin(current_display),
    y_offset = y_idle(current_display),
    hidden = true,
  }, current_display))
end

-- Ensure clean idle geometry at load (recovers stuck full-width from prior session).
apply_idle_geometry { hidden = true }

return M
