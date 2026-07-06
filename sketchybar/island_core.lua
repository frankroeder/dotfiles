-- Dynamic notch pill engine (islandbar pattern).
-- Animate bar geometry; avoid item y_offset inside animate batches.

local display = require "display"
local island_style = require "island_style"
local motion = require "motion"
local settings = require "settings"

local TRANSPARENT = 0x00ffffff

local BAR_H = settings.island.bar_height or 45
local IDLE_H = settings.island.idle_height or 51
local EXPAND_H = settings.island.expand_height or 125
local function y_idle(idx)
  return island_style.y_offset_idle(idx)
end

local function y_expand(idx)
  return island_style.y_offset_expand(idx)
end

-- The island follows the focused display; expand() retargets the bar there.
-- Every sbar.bar mutation carries `display` so the pill only ever draws on that
-- one display (never spanning all of them).
local current_display = display.focused_index()

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

local function effective_width(idx, w)
  if idx == display.builtin_index and display.notch_width > 0 then
    return w
  end
  return math.max(160, (w or 160) - 320)
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

local timer = sbar.add("item", "island.timer", {
  position = "center",
  drawing = false,
  updates = true,
  update_freq = 1,
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

local dismiss_deadline = 0
local is_expanded = false
local retracting = false

-- Last applied geometry. sketchybar interpolates CONSTANT numeric props through
-- truncated midpoints inside animate batches (y_offset -16 → -15 → -16,
-- border_width 1 → 0), which reads as 1px jitter / border flicker on every pill.
-- Animate batches below therefore only carry properties whose value changes.
local cur_w = NOTCH_W
local cur_h = BAR_H
local cur_mg = idle_margin(current_display)

local M = {}
M.BAR_H = BAR_H
M.IDLE_H = IDLE_H
M.EXPAND_H = EXPAND_H

local function expand_on(target, item)
  current_display = target

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
  local r_fixed
  if l_fixed then
    r_fixed = (L and R) and R.width or nil
  else
    r_fixed = (L and R) and (R.width or 36) or nil
  end

  local l_width
  local r_width
  if l_fixed and r_fixed then
    l_width = l_fixed
    r_width = r_fixed
  elseif l_fixed then
    l_width = l_fixed
    r_width = math.max(0, w - lpl - lpr - rpl - rpr - l_fixed)
  elseif r_fixed then
    l_width = math.max(0, w - lpl - lpr - rpl - rpr - r_fixed)
    r_width = r_fixed
  else
    l_width = nil
    r_width = w - 20
  end

  local l_align = "left"
  local r_align = (R and R.align) or (L and "right" or "center")
  local sfont = S and resolve_font(S.font or { size = 12, style = "Regular" }) or nil
  local sub_y = sfont and (TEXT_Y - (sfont.size + 16)) or 0

  local frames = item.frames or motion.frames.normal
  local style = island_style.bar(target)
  local pill_color = item.color or style.color
  local pill_border = item.border_color or style.border_color

  -- Content (strings, fonts, box widths, paddings) applies un-animated; only
  -- changing geometry and the colors enter the animate batch (see cur_* note).
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

  -- Seed idle geometry so the pill grows in from the notch instead of popping in.
  -- When already expanded (or still retracting), morph from the current geometry
  -- instead — snapping back to the seed mid-animation jitters.
  if not is_expanded and not retracting then
    cur_w = pill_base(target)
    cur_h = BAR_H
    cur_mg = idle_margin(target)
    sbar.bar(bar_props({
      hidden = false,
      display = target,
      height = cur_h,
      margin = cur_mg,
      y_offset = y_idle(target),
    }, target))
    island:set {
      width = cur_w,
      icon = with_color(icon_content, TRANSPARENT),
      label = with_color(label_content, TRANSPARENT),
    }
  else
    sbar.bar {
      hidden = false,
      display = target,
      y_offset = y_expand(target),
      corner_radius = style.corner_radius,
      border_width = style.border_width,
    }
    island:set { icon = icon_content, label = label_content }
  end

  -- Subtitle geometry is set instantly (item y_offset must not animate — it
  -- glitches inside animate batches); only its color fades in below.
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

  local bar_anim = { color = pill_color, border_color = pill_border }
  if cur_h ~= h then
    bar_anim.height = h
  end
  if cur_mg ~= mg then
    bar_anim.margin = mg
  end
  local island_anim = {
    icon = { color = L and (L.color or island_style.muted()) or TRANSPARENT },
    label = { color = R and (R.color or island_style.text()) or TRANSPARENT },
  }
  if cur_w ~= w then
    island_anim.width = w
  end

  sbar.animate(motion.curve, frames, function()
    sbar.bar(bar_anim)
    island:set(island_anim)
    if S then
      island_sub:set {
        label = { color = S.color or island_style.muted() },
      }
    end
  end)

  cur_w, cur_h, cur_mg = w, h, mg
  is_expanded = true
  dismiss_deadline = (item.duration and item.duration > 0) and (os.time() + item.duration + 1) or 0
end

function M.expand(item)
  -- Show the pill on whichever display currently has keyboard focus.
  expand_on(display.focused_index(), item or {})
end

local function retarget_focused_display()
  local target = display.focused_index()
  if target == current_display then return end
  current_display = target
  if not is_expanded then
    local base = pill_base(target)
    island:set { width = base }
    cur_w = base
    cur_mg = idle_margin(target)
    sbar.bar(bar_props({ display = target, margin = cur_mg, y_offset = y_idle(target), hidden = true }, target))
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
    return
  end
  opts = opts or {}
  is_expanded = false
  retracting = true
  dismiss_deadline = 0

  island_sub:set {
    y_offset = 0,
    label = { color = TRANSPARENT, string = "", width = 0, padding_left = 0, padding_right = 0 },
  }

  local base = pill_base(current_display)
  local frames = opts.frames or motion.frames.normal
  local style = island_style.bar(current_display)
  local mg = idle_margin(current_display)

  -- Content resets instantly; only the changing geometry and colors animate.
  island:set {
    icon = { string = "", align = "center", width = 0, padding_left = 12, padding_right = 4 },
    label = {
      string = "",
      align = "center",
      width = base - 20,
      padding_left = 4,
      padding_right = 12,
    },
  }

  local bar_anim = { color = style.color, border_color = style.border_color }
  if cur_h ~= BAR_H then
    bar_anim.height = BAR_H
  end
  if cur_mg ~= mg then
    bar_anim.margin = mg
  end
  local island_anim = {
    icon = { color = TRANSPARENT },
    label = { color = TRANSPARENT },
  }
  if cur_w ~= base then
    island_anim.width = base
  end

  sbar.animate(motion.curve, frames, function()
    sbar.bar(bar_anim)
    island:set(island_anim)
  end)
  cur_w, cur_h, cur_mg = base, BAR_H, mg

  -- Fully hide the bar once the shrink animation has finished (no idle stripe).
  sbar.delay(0.4, function()
    retracting = false
    if not is_expanded then
      sbar.bar { hidden = true }
    end
  end)
end

island:subscribe("island_tap", function()
  M.restore_idle()
end)

timer:subscribe("routine", function()
  if dismiss_deadline > 0 and os.time() >= dismiss_deadline then
    dismiss_deadline = 0
    M.restore_idle()
  end
end)

local focus_watcher = sbar.add("item", "island.focus", {
  drawing = false,
  updates = true,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

focus_watcher:subscribe({ "display_change", "window_focus" }, retarget_focused_display)

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
  }, current_display))
end

return M
