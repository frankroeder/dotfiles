local colors = require "colors"
-- SF Pro is actually installed (/Library/Fonts/SF-Pro*.otf); "SF Mono" was not,
-- so every bar silently rendered a narrower system fallback. Fixed widths below
-- are calibrated against SF Pro — re-measure with probe items if this changes.
local font_family = "SF Pro"
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
  bar_margin = 6,
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
      label = 58, -- "RAM 65%" = 54px in SF Pro Bold 11
      label_lg = 62, -- "eCPU 23%" = 59px
      label_pct = 64, -- "SSD 100%" = 63px in SF Pro Bold 12
      wifi = 32,
      wifi_icon = 20,
      rate_icon = 21,
      rate = 56, -- "999 KB/s" = 51px in SF Pro Bold 11
      rate_row = 77,
    },
    hardware = {
      cpu_graph = 60,
      gpu_graph = 28,
      graph_h = 22,
      graph_alpha = 0.42,
      graph_y = 8,
      ecpu_graph_y = 21,
      ram_top_w = 0,
      ram_bot_w = 86, -- icon 28 + label 58
      cpu_ecpu_w = 0,
      -- = the row's NATURAL packed width (probe: icon box 28 + "eCPU 22%" in
      -- 62px label, SF Pro Bold 11). Fixed row must equal the width-0 partner's
      -- natural extent or the stacked rows x-misalign (was 88 vs natural 84).
      cpu_pcpu_w = 90,
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
    -- Heights include the tuck. Visible idle = bar_height (32); expand pops below.
    -- Tuck = corner_radius so the top rounding + top border sit above the screen edge.
    bar_height = 48,
    idle_height = 48,
    expand_height = 64,
    corner_radius = 16,
    y_offset_idle = -16,
    y_offset_expand = -16,
    y_offset_external = -16,
    text_y_offset = -8,
    -- FIXED pill widths = 2 × (16px text pad + measured longest left text +
    -- 12px slack) + 220px probed notch. Measured in SF Pro Semibold 15 via
    -- probe items: "Stack layout"=88, "Mic muted"=74, "Not sticky"=72,
    -- appswitch worst (13ch+…)≈130, bt worst (9ch+… · 100%)=156. siri is
    -- floored by the right lobe minimum (wing ≥ 4+48+16 → w ≥ 356).
    -- Do NOT slim these per toast: the probed notch_width (220) underreads the
    -- physical cutout, and only the generous worst-case wings absorb that.
    widths = {
      app = 540,
      siri = 380,
      layout = 460,
      mic = 430,
      bluetooth = 590,
      window = 430,
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
