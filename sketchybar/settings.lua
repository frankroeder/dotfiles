local colors = require "colors"
local font_family = "SF Mono"
local app_icon_font = "sketchybar-app-font"

local function build_theme()
  return {
    bar = colors.with_alpha(colors.crust, colors.is_dark and 0.94 or 0.92),
    bar_border = colors.transparent,
    surface = colors.with_alpha(colors.base, colors.is_dark and 0.82 or 0.96),
    surface_alt = colors.with_alpha(colors.mantle, colors.is_dark and 0.88 or 0.94),
    border = colors.with_alpha(colors.blue, colors.is_dark and 0.27 or 0.38),
    accent = colors.with_alpha(colors.blue, colors.is_dark and 0.92 or 0.98),
    accent_alt = colors.with_alpha(colors.sky, colors.is_dark and 0.92 or 0.98),
    success = colors.with_alpha(colors.green, 0.85),
    warn = colors.with_alpha(colors.peach, 0.85),
    critical = colors.with_alpha(colors.red, 0.88),
    text_primary = colors.text,
    text_muted = colors.subtext1,
    popup_bg = colors.with_alpha(colors.popup.bg, 0.88),
    popup_border = colors.with_alpha(colors.blue, colors.is_dark and 0.27 or 0.38),
    border_width = 1,
    button_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.85 or 0.80),
    workspace = {
      bg = colors.ws.bg,
      active = colors.ws.fg,
      active_bg = colors.ws.sel_bg,
      hover_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.80 or 0.70),
      -- Selection = solid lavender fill; others quieter so focus reads without a ring.
      occupied_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.48 or 0.55),
      visible_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.60 or 0.65),
      empty_bg = colors.with_alpha(colors.crust, colors.is_dark and 0.42 or 0.52),
      badge_active_text = colors.ws.sel_fg,
      occupied_text = colors.ws.fg,
      empty_text = colors.with_alpha(colors.ws.fg, 0.42),
    },
  }
end

local spacing = {
  widget = 5,
  bracket_item = 0,
  icon_left = 10,
  icon_right = 4,
  icon = 6,
  label_left = 6,
  label_right = 10,
  workspace_label_right = 20,
  stack = 6,
  group = 8,
  inner = 4,
  edge = 6,
}

-- Solid floating bars; widgets sit on the bar (no per-item capsules).
local settings = {
  animation_duration = 10,
  bar_height = 32,
  bar_padding = 8,
  bar_margin = 12,
  bar_y_offset = 0,
  bar_corner_radius = 8,
  bar_border_width = 0,
  bar_blur_radius = 0,
  bar_shadow = false,
  bar_embed_items = true,
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
    item_height = 30,
    item_corner_radius = 8,
    item_border_width = 1,
    item_blur_radius = 0,
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
    -- Idle seed matches the top bar strip; expand_height pops out below it.
    bar_height = 32,
    idle_height = 32,
    expand_height = 48,
    corner_radius = 8,
    y_offset_idle = 0,
    y_offset_expand = 0,
    y_offset_external = 0,
    text_y_offset = 0,
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
  hardware = {
    update_freq = 2,
    silistats_path = "/usr/local/bin/silistats",
  },
  network = {
    provider_path = "$CONFIG_DIR/../helpers/event_providers/network_load/bin/network_load",
  },
  volume = {
    output_devices = true,
    scroll_step = 10,
  },
  media = {
    title_max_chars = 40,
    update_freq = 15, -- media-control poll when available
  },
  monitor_map = { ["LG ULTRAFINE"] = 2, ["DELL S2722DZ"] = 2, ["Built-in Retina Display"] = 1 },
  spaces = {
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

settings.spaces.padding = spacing.widget
settings.spaces.icon.padding_left = spacing.icon_left
settings.spaces.icon.padding_right = spacing.icon_right
settings.spaces.label.padding_left = spacing.label_left
settings.spaces.label.padding_right = spacing.workspace_label_right

-- Copy the live palette onto the shared theme table (items hold this ref).
function settings.refresh_theme()
  for key, value in pairs(build_theme()) do
    settings.theme[key] = value
  end
end

return settings
