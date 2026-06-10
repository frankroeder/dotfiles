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
    surface = colors.with_alpha(colors.surface0, 0.82),
    surface_alt = colors.with_alpha(colors.surface0, 0.88),
    surface_hover = colors.with_alpha(colors.surface1, 0.88),
    surface_active = colors.with_alpha(colors.sky, 0.22),
    border = colors.with_alpha(colors.white, 0.08),
    border_hover = colors.with_alpha(colors.sky, 0.30),
    accent = colors.with_alpha(colors.blue, 0.92),
    accent_alt = colors.with_alpha(colors.sky, 0.92),
    success = colors.with_alpha(colors.green, 0.85),
    warn = colors.with_alpha(colors.peach, 0.85),
    critical = colors.with_alpha(colors.red, 0.88),
    text_primary = colors.white,
    text_muted = colors.with_alpha(colors.subtext0, 0.92),
    text_alt = colors.with_alpha(colors.subtext1, 0.92),
    popup_bg = colors.with_alpha(colors.popup.bg, 0.88),
    popup_border = colors.with_alpha(colors.popup.border, 0.48),
    workspace = {
      bg = colors.with_alpha(colors.base, 0.68),
      border = colors.with_alpha(colors.white, 0.06),
      active = 0xff7aa2f7,
      active_alt = 0xffe1e3e4,
      active_bg = colors.with_alpha(0xff7aa2f7, 0.22),
      active_border = 0xffe1e3e4,
      hover_bg = colors.with_alpha(colors.white, 0.08),
      occupied_bg = colors.with_alpha(colors.white, 0.08),
      visible_bg = colors.with_alpha(0xff7aa2f7, 0.16),
      empty_bg = colors.with_alpha(colors.white, 0.03),
      inactive_border = colors.with_alpha(colors.white, 0.12),
      visible_border = colors.with_alpha(0xff7aa2f7, 0.28),
      badge_active_bg = colors.with_alpha(colors.crust, 0.28),
      badge_hover_bg = colors.with_alpha(0xff7aa2f7, 0.20),
      badge_visible_bg = colors.with_alpha(0xff7aa2f7, 0.16),
      badge_occupied_bg = colors.with_alpha(colors.white, 0.14),
      badge_empty_bg = colors.with_alpha(colors.white, 0.06),
      badge_border = colors.with_alpha(colors.white, 0.20),
      badge_active_border = 0xffe1e3e4,
      badge_active_text = 0xff15161e,
      occupied_text = colors.white,
      empty_text = colors.overlay0,
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
    padding = 2,
    highlight_color = 0xff7aa2f7,
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
