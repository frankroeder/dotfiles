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
  animation_duration = 10,
  bar_height = 40,
  bar_padding = 8,
  bar_margin = 4,
  bar_corner_radius = 6,
  bar_border_width = 0,
  bar_blur_radius = 0,
  bar_color = colors.transparent,
  bar_border_color = colors.transparent,
  icons = "sf-symbols",
  theme = {
    bar = colors.transparent,
    bar_border = colors.transparent,
    surface = colors.with_alpha(colors.base, 0.80),
    surface_alt = colors.with_alpha(colors.mantle, 0.88),
    surface_hover = colors.with_alpha(colors.surface0, 0.92),
    surface_active = colors.with_alpha(colors.blue, 0.28),
    border = colors.with_alpha(colors.blue, 0.27),
    border_hover = colors.with_alpha(colors.sky, 0.45),
    accent = colors.with_alpha(colors.blue, 0.92),
    accent_alt = colors.with_alpha(colors.sky, 0.92),
    success = colors.with_alpha(colors.green, 0.85),
    warn = colors.with_alpha(colors.peach, 0.85),
    critical = colors.with_alpha(colors.red, 0.88),
    text_primary = colors.white,
    text_muted = colors.subtext1,
    text_alt = colors.with_alpha(colors.subtext1, 0.92),
    popup_bg = colors.with_alpha(colors.popup.bg, 0.88),
    popup_border = colors.with_alpha(colors.popup.border, 0.48),
    workspace = {
      bg = colors.with_alpha(colors.crust, 0.67),
      border = colors.with_alpha(colors.blue, 0.27),
      active = colors.blue,
      active_alt = colors.sky,
      active_bg = colors.blue,
      active_border = colors.with_alpha(colors.blue, 0.53),
      hover_bg = colors.with_alpha(colors.surface0, 0.80),
      occupied_bg = colors.with_alpha(colors.crust, 0.67),
      visible_bg = colors.with_alpha(colors.crust, 0.67),
      empty_bg = colors.with_alpha(colors.crust, 0.67),
      inactive_border = colors.with_alpha(colors.blue, 0.27),
      visible_border = colors.with_alpha(colors.blue, 0.40),
      badge_active_bg = colors.blue,
      badge_hover_bg = colors.with_alpha(colors.blue, 0.35),
      badge_visible_bg = colors.with_alpha(colors.crust, 0.67),
      badge_occupied_bg = colors.with_alpha(colors.crust, 0.67),
      badge_empty_bg = colors.with_alpha(colors.crust, 0.67),
      badge_border = colors.with_alpha(colors.blue, 0.27),
      badge_active_border = colors.with_alpha(colors.blue, 0.53),
      badge_active_text = colors.black,
      occupied_text = colors.blue,
      empty_text = colors.blue,
    },
  },
  ui = {
    item_height = 26,
    item_corner_radius = 5,
    item_border_width = 1,
    group_height = 30,
    group_corner_radius = 6,
    group_border_width = 0,
    popup_row_height = 24,
    popup_corner_radius = 5,
    icon_size = 14.0,
    label_size = 11.0,
    label_padding = 6,
  },
  motion = {
    fast = 8,
    normal = 12,
    slow = 18,
  },
  wallpaper = {
    path = home .. "/Library/Mobile Documents/com~apple~CloudDocs/wallpapers",
    scale = 1.0,
  },
  hardware = {
    update_freq = 2,
    macmon_path = "/opt/homebrew/bin/macmon",
    silistats_path = "/usr/local/bin/silistats",
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
    padding = 4,
    highlight_color = 0xff7aa2f7,
    icon = {
      size = 16.0,
      padding_left = 10,
      padding_right = 4,
      y_offset = 0,
    },
    label = {
      font = "sketchybar-app-font:Regular:18.0",
      padding_left = 6,
      padding_right = 20,
      y_offset = 0,
    },
    capsule = {
      height = 30,
      corner_radius = 8,
    },
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
