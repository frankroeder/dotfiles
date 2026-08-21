-- Pure helpers for the flameberry-style top bar. No sbar I/O.
local icons = require "icons"
local colors = require "colors"
local utf = utf8 or require "utf8"

local M = {}

M.pill_padding = {
  inactive = 14,
  active_empty = 24,
  active_icons = 18,
}
M.number_icon_gap = 6
M.PAD_CHAR = "\xe2\x80\x83"
M.MAX_LABEL_CHARS = 20
M.IDLE_COPY = "It's pretty silent in here..."

function M.space_pill(icon_line, selected, ws_label)
  icon_line = icon_line or ""
  local has_icons = icon_line ~= ""
  local drawing = selected or has_icons
  local show_number = selected and ws_label ~= nil and ws_label ~= ""
  local pad
  if not selected then
    pad = M.pill_padding.inactive
  elseif has_icons then
    pad = M.pill_padding.active_icons
  else
    pad = M.pill_padding.active_empty
  end
  local icon_padding_right
  if has_icons and show_number then
    icon_padding_right = M.number_icon_gap
  elseif has_icons then
    icon_padding_right = 0
  else
    icon_padding_right = pad
  end
  local multi = has_icons and icon_line:find(" ", 1, true) ~= nil
  return {
    drawing = drawing,
    selected = selected and true or false,
    has_icons = has_icons,
    show_number = show_number and true or false,
    pad = pad,
    icon_string = show_number and ws_label or "",
    icon_padding_left = pad,
    icon_padding_right = icon_padding_right,
    -- Occupied unfocused keeps app icons (ss1 / criterion 2). Flameberry zeroes
    -- label.string when not selected, which would hide those glyphs.
    label_string = has_icons and icon_line or "",
    label_drawing = has_icons,
    label_padding_left = 0,
    label_padding_right = has_icons and pad or 0,
    label_y = multi and -1 or 0,
  }
end

function M.space_set_props(pill, theme)
  return {
    drawing = pill.drawing,
    icon = {
      string = pill.icon_string,
      color = pill.selected and theme.focused_text or theme.unfocused_text,
      drawing = true,
      padding_left = pill.icon_padding_left,
      padding_right = pill.icon_padding_right,
    },
    label = {
      string = pill.label_string,
      color = pill.selected and theme.focused_text or theme.unfocused_text,
      drawing = pill.label_drawing,
      padding_left = pill.label_padding_left,
      padding_right = pill.label_padding_right,
      y_offset = pill.label_y,
    },
    background = {
      color = pill.selected and theme.focused_bg or theme.unfocused_bg,
    },
  }
end

-- Flameberry: >60 → 100, >30 → 66, >10 → 33, >0 → 10, else 0.
function M.volume_band(pct, muted)
  if muted then
    return 0
  end
  pct = tonumber(pct) or 0
  if pct > 60 then
    return 100
  elseif pct > 30 then
    return 66
  elseif pct > 10 then
    return 33
  elseif pct > 0 then
    return 10
  end
  return 0
end

function M.volume_icon(pct, muted)
  return icons.volume[M.volume_band(pct, muted)]
end

function M.volume_label(pct)
  pct = math.floor(tonumber(pct) or 0)
  if pct < 0 then
    pct = 0
  elseif pct > 100 then
    pct = 100
  end
  local lead = pct < 10 and "0" or ""
  return lead .. pct .. "%"
end

function M.battery_label(charge)
  if charge == nil then
    return "?"
  end
  local n = math.floor(tonumber(charge) or 0)
  if n < 0 then
    n = 0
  elseif n > 100 then
    n = 100
  end
  local lead = n < 10 and "0" or ""
  return lead .. n .. "%"
end

-- Flameberry bands: charging; >60 → 100; >40 → 75; >20 → 50; >10 → 25; else 0.
function M.battery_visual(charge, charging)
  charge = tonumber(charge)
  if charging then
    return {
      icon = icons.battery.charging,
      color = colors.green,
      label = M.battery_label(charge),
      band = "charging",
    }
  end
  if not charge then
    return { icon = "!", color = colors.red, label = "?", band = "unknown" }
  end
  local icon, color, band
  if charge > 60 then
    icon, color, band = icons.battery["100"], colors.blue, "100"
  elseif charge > 40 then
    icon, color, band = icons.battery["75"], colors.yellow, "75"
  elseif charge > 20 then
    icon, color, band = icons.battery["50"], colors.peach, "50"
  elseif charge > 10 then
    icon, color, band = icons.battery["25"], colors.peach, "25"
  else
    icon, color, band = icons.battery["0"], colors.red, "0"
  end
  return { icon = icon, color = color, label = M.battery_label(charge), band = band }
end

function M.wifi_connected(status)
  -- ifconfig prints "active" or "inactive"; substring find("active") matches both.
  local token = tostring(status or ""):lower():match "^%s*(%S+)"
  return token == "active"
end

function M.bluetooth_state(powered, connected)
  if not powered then
    return "off"
  end
  if connected then
    return "connected"
  end
  return "on"
end

function M.weather_label(raw)
  local temp = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if temp == "" then
    return nil
  end
  if temp:lower():find("unknown", 1, true) then
    return nil
  end
  return temp
end

local function char_width(cp)
  if
    (cp >= 0x1100 and cp <= 0x115F)
    or (cp >= 0x2E80 and cp <= 0x303E)
    or (cp >= 0x3041 and cp <= 0x33FF)
    or (cp >= 0x3400 and cp <= 0x4DBF)
    or (cp >= 0x4E00 and cp <= 0x9FFF)
    or (cp >= 0xA000 and cp <= 0xA4CF)
    or (cp >= 0xAC00 and cp <= 0xD7A3)
    or (cp >= 0xF900 and cp <= 0xFAFF)
    or (cp >= 0xFE30 and cp <= 0xFE4F)
    or (cp >= 0xFF00 and cp <= 0xFF60)
    or (cp >= 0xFFE0 and cp <= 0xFFE6)
    or (cp >= 0x20000 and cp <= 0x3FFFD)
  then
    return 2
  end
  return 1
end

function M.display_width(s)
  s = tostring(s or "")
  local w = 0
  for _, cp in utf.codes(s) do
    w = w + char_width(cp)
  end
  return w
end

function M.truncate(s, n)
  s = tostring(s or "")
  n = n or M.MAX_LABEL_CHARS
  if M.display_width(s) <= n then
    return s
  end
  local budget = n - 1
  local w = 0
  local out = {}
  for _, cp in utf.codes(s) do
    local cw = char_width(cp)
    if w + cw > budget then
      break
    end
    w = w + cw
    out[#out + 1] = utf.char(cp)
  end
  return table.concat(out) .. "…"
end

function M.pad_to(s, n)
  s = tostring(s or "")
  n = n or M.MAX_LABEL_CHARS
  local w = M.display_width(s)
  if w < n then
    return s .. string.rep(M.PAD_CHAR, n - w)
  end
  return s
end

function M.media_display(title, artist, max_n)
  title = title or ""
  artist = artist or ""
  local raw = title
  if artist ~= "" then
    raw = title .. " – " .. artist
  end
  return M.truncate(raw, max_n or M.MAX_LABEL_CHARS)
end

function M.date_string(t)
  return os.date("%a %d %b", t)
end

function M.time_string(t)
  return os.date("%H:%M", t)
end

return M
