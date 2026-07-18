local home = os.getenv "HOME"
local colors = require "colors"
local font_family = "SF Mono"
local app_icon_font = "sketchybar-app-font"

local function build_theme()
  return {
    bar = colors.transparent,
    bar_border = colors.transparent,
    surface = colors.with_alpha(colors.base, colors.is_dark and 0.82 or 0.96),
    surface_alt = colors.with_alpha(colors.mantle, colors.is_dark and 0.88 or 0.94),
    surface_hover = colors.with_alpha(colors.surface0, colors.is_dark and 0.92 or 0.85),
    surface_active = colors.with_alpha(colors.blue, 0.28),
    border = colors.with_alpha(colors.blue, colors.is_dark and 0.27 or 0.38),
    border_hover = colors.with_alpha(colors.sky, 0.45),
    accent = colors.with_alpha(colors.blue, colors.is_dark and 0.92 or 0.98),
    accent_alt = colors.with_alpha(colors.sky, colors.is_dark and 0.92 or 0.98),
    success = colors.with_alpha(colors.green, 0.85),
    warn = colors.with_alpha(colors.peach, 0.85),
    critical = colors.with_alpha(colors.red, 0.88),
    text_primary = colors.text,
    text_muted = colors.subtext1,
    text_alt = colors.with_alpha(colors.subtext1, 0.92),
    popup_bg = colors.with_alpha(colors.popup.bg, 0.88),
    popup_border = colors.with_alpha(colors.blue, colors.is_dark and 0.27 or 0.38),
    border_width = 1,
    button_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.85 or 0.80),
    workspace = {
      bg = colors.ws.bg,
      border = colors.ws.border,
      fg = colors.ws.fg,
      active = colors.ws.fg,
      active_alt = colors.sky,
      active_bg = colors.ws.sel_bg,
      active_border = colors.with_alpha(colors.ws.fg, 0.53),
      hover_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.80 or 0.70),
      -- Selection = solid lavender fill; others quieter so focus reads without a ring.
      occupied_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.48 or 0.55),
      visible_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.60 or 0.65),
      empty_bg = colors.with_alpha(colors.crust, colors.is_dark and 0.42 or 0.52),
      inactive_border = colors.with_alpha(colors.ws.fg, 0.27),
      visible_border = colors.with_alpha(colors.ws.fg, 0.40),
      badge_active_bg = colors.ws.sel_bg,
      badge_hover_bg = colors.with_alpha(colors.ws.fg, 0.35),
      badge_visible_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.60 or 0.65),
      badge_occupied_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.48 or 0.55),
      badge_empty_bg = colors.with_alpha(colors.crust, colors.is_dark and 0.42 or 0.52),
      badge_border = colors.with_alpha(colors.ws.fg, 0.27),
      badge_active_border = colors.with_alpha(colors.ws.fg, 0.53),
      badge_active_text = colors.ws.sel_fg,
      occupied_text = colors.ws.fg,
      empty_text = colors.with_alpha(colors.ws.fg, 0.42),
    },
  }
end

-- Bar visual preset: "transparent" (default) or "gnix" (solid surface + blur, Efterklang-style).
local preset = "transparent"

local preset_options = {
  transparent = {
    bar_height = 38,
    bar_margin = 8,
    bar_corner_radius = 8,
    bar_border_width = 0,
    bar_blur_radius = 0,
    bar_shadow = false,
    item_height = 30,
    item_corner_radius = 8,
    item_border_width = 1,
    popup_blur_radius = 0,
  },
  gnix = {
    bar_height = 32,
    bar_margin = 5,
    bar_corner_radius = 10,
    bar_border_width = 3,
    bar_blur_radius = 15,
    bar_shadow = true,
    item_height = 28,
    item_corner_radius = 9,
    item_border_width = 2,
    popup_blur_radius = 50,
  },
}

local modules = {
  logo = { enable = false },
  calendar = { enable = true },
  battery = { enable = true },
  brew = { enable = true },
  network = { enable = true },
  wifi = { enable = true },
  volume = { enable = true },
  mic = { enable = true },
  bluetooth = { enable = true },
  app_badges = { enable = false },
}

local spacing = {
  widget = 5,
  bracket = 5,
  bracket_item = 0,
  icon_left = 10,
  icon_right = 4,
  icon = 6,
  label_left = 6,
  label_right = 10,
  label = 6,
  workspace_label_right = 20,
  stack = 6,
  group = 8,
  inner = 4,
  edge = 6,
}

local active_preset = preset_options[preset] or preset_options.transparent

local settings = {
  preset = preset,
  modules = modules,
  animation_duration = 10,
  bar_height = active_preset.bar_height,
  bar_padding = 5,
  bar_margin = active_preset.bar_margin,
  bar_corner_radius = active_preset.bar_corner_radius,
  bar_border_width = active_preset.bar_border_width,
  bar_blur_radius = active_preset.bar_blur_radius,
  bar_shadow = active_preset.bar_shadow,
  bar_color = colors.transparent,
  bar_border_color = colors.transparent,
  border_width = 1,
  icons = "sf-symbols",
  theme = build_theme(),
  layout = {
    spacing = spacing,
    columns = {
      icon = 28,
      icon_sm = 22,
      label = 50,
      label_lg = 62,
      label_pct = 58,
      wifi = 30,
      wifi_icon = 20,
      rate_icon = 21,
      rate = 58,
      rate_row = 74,
    },
    hardware = {
      cpu_graph = 60,
      gpu_graph = 28,
      graph_h = 22,
      graph_alpha = 0.42,
      graph_y = 8,
      ecpu_graph_y = 21,
      ram_top_w = 0,
      ram_bot_w = 78,
      cpu_ecpu_w = 0,
      cpu_pcpu_w = 88,
      gpu_temp_pad_l = -6,
      gpu_label_pad_r = -8,
      cpu_ecpu_pad_l = -12,
      cpu_ecpu_pad_r_extra = 4,
    },
    fonts = {
      hw_label = 14.0,
      hw_small = 11.0,
      rate = 11.0,
    },
  },
  ui = {
    item_height = active_preset.item_height,
    item_corner_radius = active_preset.item_corner_radius,
    item_border_width = active_preset.item_border_width,
    item_blur_radius = active_preset.popup_blur_radius,
    popup_row_height = 24,
    popup_corner_radius = 10,
    popup_y_offset = -2,
    icon_size = 16.0,
    label_size = 14.0,
    popup_icon_padding = 5,
    popup_label_padding = 11,
  },
  motion = {
    fast = 8,
    normal = 12,
    slow = 18,
  },
  island = {
    -- Pills always on; only durations / geometry live here.
    appswitch_duration = 4,
    layout_duration = 2,
    window_duration = 2,
    mic_duration = 2,
    bluetooth_duration = 3,
    siri_frames = 108,
    -- Idle bar height matches the single-line pill; heights include the tuck.
    bar_height = 56,
    idle_height = 56,
    expand_height = 112,
    corner_radius = 16,
    -- Tuck by the corner radius so the top rounding hides above the screen edge.
    y_offset_idle = -16,
    y_offset_expand = -16,
    y_offset_external = -16,
    text_y_offset = -8,
    -- Widths sized so the longest label fits its lobe (fallback mono is wide).
    widths = {
      app = 520,
      siri = 380,
      layout = 520,
      mic = 460,
      bluetooth = 540,
      window = 480,
    },
  },
  wallpaper = {
    path = home .. "/Library/Mobile Documents/com~apple~CloudDocs/wallpapers",
    scale = 1.0,
  },
  hardware = {
    update_freq = 2,
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
  volume = {
    output_devices = true,
    scroll_step = 10,
  },
  app_badges = {
    apps = {
      -- { name = "widgets.badge.messages", bundle_id = "com.apple.MobileSMS",
      --   icon = "􀌥", color = colors.green, app_name = "Messages" },
    },
  },
  media = {
    controller = "media-control",
    album_art_size = 1280,
    title_max_chars = 40,
    -- ~150% wider popup: art 120→180, text column ~200→320 (must be ≥ longest label)
    popup_height = 240,
    popup_art_size = 180,
    popup_text_width = 320,
    popup_text_chars = { title = 27, artist = 30, album = 30 },
    delay_after_cmd = 0.2,
    default_artist = "Various Artists",
    default_album = "No Album",
    nowplaying_path = home
      .. "/.dotfiles/sketchybar/helpers/event_providers/media_nowplaying/media_nowplaying",
  },
  large_screen_width = 2000,
  monitor_map = { ["LG ULTRAFINE"] = 2, ["DELL S2722DZ"] = 2, ["Built-in Retina Display"] = 1 },
  spaces = {
    item_padding = 12,
    highlight_color = colors.lavender,
    icon = {
      size = 16.0,
      y_offset = 0,
    },
    label = {
      font = app_icon_font .. ":Regular:18.0",
      y_offset = -2,
    },
    capsule = {
      height = 30,
      corner_radius = 8,
    },
  },
  font = {
    family = font_family,
    app_icon = app_icon_font,
    style_map = {
      ["Regular"] = "Regular",
      ["Semibold"] = "Semibold",
      ["Bold"] = "Bold",
      ["Heavy"] = "Heavy",
      ["Black"] = "Black",
    },
  },
}

settings.theme.border_width = settings.border_width
settings.paddings = spacing.widget

settings.ui.icon_padding_left = spacing.icon_left
settings.ui.icon_padding_right = spacing.icon_right
settings.ui.label_padding_left = spacing.label_left
settings.ui.label_padding_right = spacing.label_right
settings.ui.label_padding = spacing.label

settings.spaces.padding = spacing.widget
settings.spaces.icon.padding_left = spacing.icon_left
settings.spaces.icon.padding_right = spacing.icon_right
settings.spaces.label.padding_left = spacing.label_left
settings.spaces.label.padding_right = spacing.workspace_label_right

function settings.apply_preset(name)
  local opts = preset_options[name]
  if not opts then
    return
  end
  settings.preset = name
  settings.bar_height = opts.bar_height
  settings.bar_margin = opts.bar_margin
  settings.bar_corner_radius = opts.bar_corner_radius
  settings.bar_border_width = opts.bar_border_width
  settings.bar_blur_radius = opts.bar_blur_radius
  settings.bar_shadow = opts.bar_shadow
  settings.ui.item_height = opts.item_height
  settings.ui.item_corner_radius = opts.item_corner_radius
  settings.ui.item_border_width = opts.item_border_width
  settings.ui.item_blur_radius = opts.popup_blur_radius
  if name == "gnix" then
    settings.bar_color = colors.base
    settings.bar_border_color = colors.surface0
    settings.theme.bar = colors.base
    settings.theme.bar_border = colors.surface0
    settings.border_width = 2
    settings.theme.border_width = 2
  else
    settings.bar_color = colors.transparent
    settings.bar_border_color = colors.transparent
    settings.theme.bar = colors.transparent
    settings.theme.bar_border = colors.transparent
    settings.border_width = 1
    settings.theme.border_width = 1
  end
end

function settings.refresh_theme()
  local theme = build_theme()
  for key, value in pairs(theme) do
    settings.theme[key] = value
  end
  settings.apply_preset(settings.preset)
  settings.spaces.highlight_color = colors.lavender
end

settings.apply_preset(preset)

return settings
