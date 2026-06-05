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
  bar_padding = 8,
  bar_margin = 4,
  bar_corner_radius = 8,
  bar_border_width = 0,
  bar_blur_radius = 0,
  bar_color = colors.transparent,
  bar_border_color = colors.transparent,
  icons = "sf-symbols",
  theme = {
    bar = colors.transparent,
    bar_border = colors.transparent,
    surface = colors.with_alpha(colors.surface0, 0.86),
    surface_alt = colors.with_alpha(colors.surface0, 0.74),
    surface_hover = colors.with_alpha(colors.surface1, 0.92),
    surface_active = colors.with_alpha(colors.sky, 0.20),
    border = colors.with_alpha(colors.white, 0.10),
    border_hover = colors.with_alpha(colors.sky, 0.34),
    accent = colors.with_alpha(colors.teal, 0.96),
    accent_alt = colors.with_alpha(colors.sky, 0.96),
    success = colors.with_alpha(colors.green, 0.88),
    warn = colors.with_alpha(colors.peach, 0.88),
    critical = colors.with_alpha(colors.red, 0.90),
    text_primary = colors.white,
    text_muted = colors.with_alpha(colors.subtext0, 0.95),
    text_alt = colors.with_alpha(colors.subtext1, 0.95),
    popup_bg = colors.with_alpha(colors.popup.bg, 0.90),
    popup_border = colors.with_alpha(colors.popup.border, 0.52),
    workspace = {
      bg = colors.with_alpha(colors.base, 0.72),
      border = colors.with_alpha(colors.white, 0.07),
      active = colors.teal,
      active_alt = colors.sky,
      active_bg = colors.with_alpha(colors.sky, 0.20),
      active_border = colors.with_alpha(colors.sky, 0.45),
      hover_bg = colors.with_alpha(colors.white, 0.10),
      occupied_bg = colors.with_alpha(colors.white, 0.10),
      visible_bg = colors.with_alpha(colors.sky, 0.14),
      empty_bg = colors.with_alpha(colors.white, 0.04),
      inactive_border = colors.with_alpha(colors.white, 0.14),
      visible_border = colors.with_alpha(colors.sky, 0.30),
      badge_active_bg = colors.with_alpha(colors.crust, 0.30),
      badge_hover_bg = colors.with_alpha(colors.sky, 0.24),
      badge_visible_bg = colors.with_alpha(colors.sky, 0.18),
      badge_occupied_bg = colors.with_alpha(colors.white, 0.16),
      badge_empty_bg = colors.with_alpha(colors.white, 0.08),
      badge_border = colors.with_alpha(colors.white, 0.24),
      badge_active_border = colors.with_alpha(colors.sky, 0.36),
      badge_active_text = colors.white,
      occupied_text = colors.white,
      empty_text = colors.overlay1,
    },
  },
  ui = {
    item_height = 26,
    item_corner_radius = 6,
    item_border_width = 1,
    group_height = 30,
    group_corner_radius = 8,
    group_border_width = 0,
    popup_row_height = 24,
    popup_corner_radius = 6,
    icon_size = 15.0,
    label_size = 12.0,
    label_padding = 7,
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
    padding = 2,
    highlight_color = colors.sky,
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
