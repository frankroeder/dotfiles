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

-- Pill baseline: the physical notch on the built-in screen, else a 200px pill.
local function pill_base(idx)
  if idx == display.builtin_index and display.notch_width > 0 then
    return display.notch_width
  end
  return 200
end

-- Item widths are sized to straddle the notch. On notchless displays that gap is
-- gone, so shrink the pill by the notch allowance to keep it from being too wide.
local NOTCH_ALLOWANCE = display.notch_width > 0 and display.notch_width or 160
local function effective_width(idx, w)
  if idx == display.builtin_index and display.notch_width > 0 then
    return w
  end
  return math.max(200, w - NOTCH_ALLOWANCE)
end

local function idle_margin(idx)
  return math.max(0, math.floor((display_width(idx) - pill_base(idx)) / 2))
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

local island = sbar.add("item", "island.main", {
  position = "center",
  width = NOTCH_W,
  updates = true,
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
local expanded_height = BAR_H

local M = {}
M.BAR_H = BAR_H
M.IDLE_H = IDLE_H
M.EXPAND_H = EXPAND_H

local function expand_on(target, item)
  current_display = target

  local w = effective_width(target, item.width or pill_base(target))
  local h = item.height or IDLE_H
  local mg = math.max(0, math.floor((display_width(target) - w) / 2))

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
  local sub_y = sfont and -(sfont.size + 16) or 0

  local frames = item.frames or motion.frames.normal

  local expand_props = bar_props({
    hidden = false,
    display = target,
    height = h,
    margin = mg,
    y_offset = y_expand(target),
    color = item.color,
    border_color = item.border_color,
  }, target)

  -- Seed idle geometry so the pill can grow in from the notch instead of popping in.
  if item.from_idle and not is_expanded then
    local base = pill_base(target)
    sbar.bar(bar_props({
      hidden = false,
      display = target,
      height = BAR_H,
      margin = idle_margin(target),
      y_offset = y_idle(target),
    }, target))
    island:set {
      width = base,
      icon = {
        string = L and (L.text or "") or "",
        color = TRANSPARENT,
        font = resolve_font(L and L.font or {}),
        width = l_width or 0,
        align = l_align,
        padding_left = lpl,
        padding_right = lpr,
      },
      label = {
        string = R and (R.text or "") or "",
        color = TRANSPARENT,
        align = r_align,
        width = r_width or 0,
        font = resolve_font(R and R.font or {}),
        padding_left = rpl,
        padding_right = rpr,
      },
    }
    island_sub:set {
      y_offset = 0,
      label = { color = TRANSPARENT, string = "", width = 0 },
    }
  else
    sbar.bar(expand_props)
  end

  sbar.animate(motion.curve, frames, function()
    sbar.bar(expand_props)
    island:set {
      width = w,
      icon = {
        string = L and (L.text or "") or "",
        color = L and (L.color or island_style.muted()) or TRANSPARENT,
        font = resolve_font(L and L.font or {}),
        width = l_width or 0,
        align = l_align,
        padding_left = lpl,
        padding_right = lpr,
      },
      label = {
        string = R and (R.text or "") or "",
        color = R and (R.color or island_style.text()) or TRANSPARENT,
        align = r_align,
        width = r_width or 0,
        font = resolve_font(R and R.font or {}),
        padding_left = rpl,
        padding_right = rpr,
      },
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
  end)

  is_expanded = true
  expanded_height = h
  dismiss_deadline = (item.duration and item.duration > 0) and (os.time() + item.duration + 1) or 0
end

function M.expand(item)
  -- Show the pill on whichever display currently has keyboard focus.
  expand_on(display.focused_index(), item or {})
end

local function retarget_focused_display()
  local target = display.focused_index()
  if target == current_display then
    return
  end
  current_display = target
  if not is_expanded then
    return
  end

  local query = island:query()
  local w = tonumber(query and query.geometry and query.geometry.width) or pill_base(target)
  local mg = math.max(0, math.floor((display_width(target) - w) / 2))
  sbar.bar(bar_props({
    display = target,
    height = expanded_height,
    margin = mg,
    y_offset = y_expand(target),
  }, target))
end

function M.restore_idle(opts)
  if not is_expanded then
    return
  end
  opts = opts or {}
  is_expanded = false
  dismiss_deadline = 0

  island_sub:set {
    y_offset = 0,
    label = { color = TRANSPARENT, string = "", width = 0, padding_left = 0, padding_right = 0 },
  }

  local base = pill_base(current_display)
  local frames = opts.frames or motion.frames.normal

  sbar.animate(motion.curve, frames, function()
    sbar.bar(bar_props({
      display = current_display,
      height = BAR_H,
      margin = idle_margin(current_display),
      y_offset = y_idle(current_display),
    }, current_display))
    island:set {
      width = base,
      icon = {
        color = TRANSPARENT,
        string = "",
        align = "center",
        width = 0,
        padding_left = 12,
        padding_right = 4,
      },
      label = {
        color = TRANSPARENT,
        string = "",
        align = "center",
        width = base - 20,
        padding_left = 4,
        padding_right = 12,
      },
    }
  end)

  -- Fully hide the bar once the shrink animation has finished (no idle stripe).
  sbar.delay(0.4, function()
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