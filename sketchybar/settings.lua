local print_table = function(t, indent)
  indent = indent or 0
  local queue = { { table = t, level = indent, parent_key = "" } }

  while #queue > 0 do
    local current = table.remove(queue, 1)
    local spaces = string.rep("  ", current.level)

    for k, v in pairs(current.table) do
      local full_key = current.parent_key == "" and tostring(k)
        or current.parent_key .. "." .. tostring(k)
      if type(v) == "table" then
        print(spaces .. full_key .. ":")
        table.insert(queue, { table = v, level = current.level + 1, parent_key = full_key })
      else
        print(spaces .. full_key .. ": " .. tostring(v))
      end
    end
  end
end

local home = os.getenv "HOME"
local colors = require "colors"

local settings = {
  paddings = 4,
  animation_duration = 15,
  bar_height = 40,
  bar_padding = 10,
  bar_margin = 10,
  bar_corner_radius = 12,
  bar_border_width = 0,
  bar_blur_radius = 0,
  bar_color = colors.transparent,
  bar_border_color = colors.transparent,
  icons = "sf-symbols",
  theme = {
    bar = colors.transparent,
    bar_border = colors.transparent,
    surface = colors.with_alpha(colors.bg1, 0.72),
    surface_alt = colors.with_alpha(colors.bg2, 0.78),
    surface_active = colors.with_alpha(colors.bg3, 0.68),
    border = colors.with_alpha(colors.grey, 0.28),
    accent = colors.with_alpha(colors.purple, 0.92),
    accent_alt = colors.with_alpha(colors.magenta, 0.86),
    success = colors.with_alpha(colors.green, 0.88),
    warn = colors.with_alpha(colors.yellow, 0.88),
    critical = colors.with_alpha(colors.red, 0.90),
    text_primary = colors.white,
    text_muted = colors.with_alpha(colors.grey, 0.90),
    popup_bg = colors.with_alpha(colors.popup.bg, 0.90),
    popup_border = colors.with_alpha(colors.popup.border, 0.52),
  },
  ui = {
    item_height = 30,
    item_corner_radius = 10,
    item_border_width = 0,
    group_height = 34,
    group_corner_radius = 12,
    group_border_width = 0,
    popup_row_height = 24,
    popup_corner_radius = 10,
    icon_size = 15.0,
    label_size = 13.0,
    label_padding = 8,
  },
  motion = {
    fast = 10,
    normal = 15,
    slow = 24,
  },
  wallpaper = {
    path = home .. "/Library/Mobile Documents/com~apple~CloudDocs/wallpapers",
    scale = 1.0,
  },
  hardware = {
    update_freq = 2,
    macmon_path = "/opt/homebrew/bin/macmon",
    label_width = 130,
    compact_labels = true,
  },
  sounds = {
    path = "/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds/",
  },
  network = {
    provider_path = "$CONFIG_DIR/../helpers/event_providers/network_load/bin/network_load",
  },
  large_screen_width = 2000,
  monitor_map = { ["LG ULTRAFINE"] = 2, ["DELL S2722DZ"] = 2, ["Built-in Retina Display"] = 1 },
  spaces = {
    padding = 3,
    highlight_color = colors.blue,
  },
  font = {
    text = "SF Pro",
    numbers = "SF Pro",
    style_map = {
      ["Regular"] = "Regular",
      ["Semibold"] = "Semibold",
      ["Bold"] = "Bold",
      ["Heavy"] = "Heavy",
      ["Black"] = "Black",
    },
  },
  print_table = print_table,
}

return settings
