-- Dynamic notch pill engine (islandbar pattern).
-- Animate bar geometry; avoid item y_offset inside animate batches.

local display = require "display"
local island_style = require "island_style"
local motion = require "motion"
local settings = require "settings"

local TRANSPARENT = 0x00ffffff

local NOTCH_W = display.notch_width
local BAR_H = settings.island.bar_height or 45
local IDLE_H = settings.island.idle_height or 51
local EXPAND_H = settings.island.expand_height or 125
local Y_IDLE = settings.island.y_offset_idle or -9
local Y_EXPAND = settings.island.y_offset_expand or Y_IDLE

local ORIG_MARGIN = math.max(0, math.floor((display.screen_width - NOTCH_W) / 2))

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
      props[key] = value
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

local M = {}
M.BAR_H = BAR_H
M.IDLE_H = IDLE_H
M.EXPAND_H = EXPAND_H

function M.expand(item)
  item = item or {}

  local w = item.width or NOTCH_W
  local h = item.height or IDLE_H
  local mg = math.max(0, math.floor((display.screen_width - w) / 2))

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

  sbar.animate(motion.curve, motion.frames.normal, function()
    sbar.bar(bar_props {
      height = h,
      margin = mg,
      y_offset = Y_EXPAND,
      color = item.color,
      border_color = item.border_color,
    })
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
  dismiss_deadline = (item.duration and item.duration > 0) and (os.time() + item.duration + 1) or 0
end

function M.restore_idle()
  if not is_expanded then
    return
  end
  is_expanded = false
  dismiss_deadline = 0

  island_sub:set {
    y_offset = 0,
    label = { color = TRANSPARENT, string = "", width = 0, padding_left = 0, padding_right = 0 },
  }

  sbar.animate(motion.curve, motion.frames.normal, function()
    sbar.bar(bar_props { height = BAR_H, margin = ORIG_MARGIN, y_offset = Y_IDLE })
    island:set {
      width = NOTCH_W,
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
        width = NOTCH_W - 20,
        padding_left = 4,
        padding_right = 12,
      },
    }
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

function M.refresh_theme()
  sbar.bar(bar_props { margin = ORIG_MARGIN })
end

return M