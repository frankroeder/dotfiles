-- Keyboard-shortcuts overview: keyboard glyph on the left bar; click opens a
-- slim two-column list of skhdrc bindings (parsed live via shortcuts_logic).
-- Popup layout uses the ccu technique: horizontal popup, width-0 rows whose
-- left pad is cancelled by a negative right pad, y_offset stacking, and an
-- invisible plate item that alone defines the popup width.
local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"
local utils = require "utils"
local logic = require "shortcuts_logic"

local theme = settings.theme
local skhdrc = (os.getenv "DOTFILES" or (os.getenv "HOME" .. "/.dotfiles")) .. "/skhd/skhdrc"

local pad = 14
local col_gap = 26
local desc_w = 244 -- longest real desc ≈ 46 chars ≈ 244px in SF Pro 11.5
local key_w = 92 -- longest chord "fn⌃ H/J/K/L" ≈ 70px in SF Pro Semibold 11
local col_w = desc_w + key_w
local plate_w = pad * 2 + col_w * 2 + col_gap
local row_h = 19
local head_h = 20
local gap_section = 10
local title_h = 20
local title_gap = 8
local frame_pad = 12
local desc_max_chars = 46

local title_font = {
  family = settings.font.family,
  style = settings.font.style_map["Bold"],
  size = 12.0,
}
local head_font = {
  family = settings.font.family,
  style = settings.font.style_map["Bold"],
  size = 10.0,
}
local desc_font = { family = settings.font.family, size = 11.5 }
local key_font = {
  family = settings.font.family,
  style = settings.font.style_map["Semibold"],
  size = 11.0,
}

local function frame_bg(h)
  return {
    drawing = true,
    color = colors.is_dark and colors.mantle or colors.base,
    height = h,
    corner_radius = settings.ui.popup_corner_radius,
    border_width = 1,
    border_color = theme.popup_border,
  }
end

local shortcuts = ui.add_capsule("widgets.shortcuts", {
  position = "left",
  padding_left = 2,
  padding_right = 2,
  icon = {
    string = icons.keyboard,
    font = { size = 15.0 },
    color = theme.text_primary,
    padding_left = 6,
    padding_right = 6,
  },
  label = { drawing = false },
  popup = {
    align = "left",
    horizontal = true,
    height = 100,
    y_offset = 1,
    background = frame_bg(100),
  },
})

local pop_names = {}
local built_text = nil

local function pop_item(name, x, spec)
  spec.position = "popup." .. shortcuts.name
  spec.width = 0
  spec.padding_left = x
  spec.padding_right = -x
  spec.background = { drawing = false }
  pop_names[#pop_names + 1] = name
  return sbar.add("item", name, spec)
end

local function clear_popup()
  for _, name in ipairs(pop_names) do
    sbar.remove(name)
  end
  pop_names = {}
end

local function build(sections)
  clear_popup()

  -- Flatten to a slot list, then split into two columns at the section
  -- header whose cumulative height is closest to half the total.
  local elems = {}
  for si, sec in ipairs(sections) do
    elems[#elems + 1] = {
      kind = "header",
      text = sec.title:upper(),
      h = head_h,
      gap = si > 1 and gap_section or 0,
    }
    for _, row in ipairs(sec.rows) do
      elems[#elems + 1] = { kind = "row", desc = row.desc, keys = row.keys, h = row_h, gap = 0 }
    end
  end

  local total = 0
  for _, e in ipairs(elems) do
    total = total + e.gap + e.h
  end
  local split, best_d
  local acc = 0
  for i, e in ipairs(elems) do
    if e.kind == "header" and i > 1 then
      local d = math.abs(acc - total / 2)
      if not best_d or d < best_d then
        best_d, split = d, i
      end
    end
    acc = acc + e.gap + e.h
  end
  split = split or (#elems + 1)

  local function col_height(from, to)
    local h = 0
    for i = from, to do
      h = h + elems[i].h + (i > from and elems[i].gap or 0)
    end
    return h
  end
  local h1 = col_height(1, split - 1)
  local h2 = col_height(split, #elems)
  local popup_h = frame_pad * 2 + title_h + title_gap + math.max(h1, h2)
  local top = popup_h / 2 - frame_pad

  local idx = 0
  local function add_elem(e, x, y_center)
    idx = idx + 1
    local name = "widgets.shortcuts." .. idx
    if e.kind == "header" then
      pop_item(name, x, {
        y_offset = math.floor(y_center + 0.5),
        icon = {
          string = e.text,
          width = col_w,
          align = "left",
          font = head_font,
          color = theme.accent,
          padding_left = 0,
          padding_right = 0,
        },
        label = { drawing = false },
      })
    else
      pop_item(name, x, {
        y_offset = math.floor(y_center + 0.5),
        icon = {
          string = utils.ellipsize(e.desc, desc_max_chars),
          width = desc_w,
          align = "left",
          font = desc_font,
          color = theme.text_primary,
          padding_left = 0,
          padding_right = 0,
        },
        label = {
          string = e.keys,
          width = key_w,
          align = "right",
          font = key_font,
          color = theme.text_muted,
          padding_left = 0,
          padding_right = 0,
        },
      })
    end
  end

  -- Title row spans both columns.
  pop_item("widgets.shortcuts.title", pad, {
    y_offset = math.floor(top - title_h / 2 + 0.5),
    icon = {
      string = "KEYBOARD SHORTCUTS",
      width = col_w + col_gap,
      align = "left",
      font = title_font,
      color = theme.text_primary,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      string = "skhd",
      width = col_w,
      align = "right",
      font = head_font,
      color = theme.text_muted,
      padding_left = 0,
      padding_right = 0,
    },
  })

  local function place_column(from, to, x)
    local off = title_h + title_gap
    for i = from, to do
      local e = elems[i]
      if i > from then
        off = off + e.gap
      end
      add_elem(e, x, top - off - e.h / 2)
      off = off + e.h
    end
  end
  place_column(1, split - 1, pad)
  place_column(split, #elems, pad + col_w + col_gap)

  -- Plate: sole width-carrying item, added last so it cannot shift the rows.
  pop_item("widgets.shortcuts.plate", 0, {
    icon = { drawing = false },
    label = { drawing = false },
  })
  sbar.set("widgets.shortcuts.plate", { width = plate_w, padding_left = 0, padding_right = 0 })

  shortcuts:set {
    popup = {
      height = popup_h,
      y_offset = 1,
      align = "left",
      horizontal = true,
      background = frame_bg(popup_h),
    },
  }
end

local function rebuild_if_needed()
  local f = io.open(skhdrc, "r")
  if not f then
    return
  end
  local text = f:read "*a"
  f:close()
  if text == built_text then
    return
  end
  built_text = text
  build(logic.parse(text))
end

ui.bind_popup(shortcuts, { on_open = rebuild_if_needed })

shortcuts:subscribe("theme_colors_updated", function()
  shortcuts:set {
    background = ui.capsule(),
    icon = { color = theme.text_primary },
  }
  built_text = nil -- next open repaints with the new palette
  local q = shortcuts:query()
  if q and q.popup and q.popup.drawing == "on" then
    rebuild_if_needed()
  end
end)
