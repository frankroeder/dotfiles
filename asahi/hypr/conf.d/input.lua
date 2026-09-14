hl.config {
  input = {
    kb_layout = "de",
    kb_variant = "mac_nodeadkeys",
    kb_model = "apple",
    repeat_delay = 300,
    repeat_rate = 40,
    accel_profile = "adaptive",
    natural_scroll = true,

    -- macOS-like trackpad: tap-click without tap-drag, two-finger clickfinger,
    -- slower scroll. Custom accel is device-only below.
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      disable_while_typing = true,
      tap_and_drag = false,
      drag_lock = false,
      clickfinger_behavior = true,
      scroll_factor = 0.2,
    },

    -- Power-user: slightly higher sensitivity for precise keyboard-driven workflows
    sensitivity = 0.1,
  },

  -- Commit a workspace swipe after 25% travel.
  gestures = {
    workspace_swipe_cancel_ratio = 0.25,
  },
}

-- Built-in Asahi MTP pad (Intel Macs are apple-spi-trackpad). macOS-like curve:
-- slow start, then a steep ramp. "<step> <output velocity per step>" — raise the
-- later points to speed it up. Keep this rule even on a stock profile: hyprctl
-- reload does not reset a device, it only stops overriding it.
hl.device {
  name = "apple-mtp-multi-touch",
  accel_profile = "custom 1.0 0.0 0.05 0.15 0.35 0.75 1.25",
  scroll_points = "1.0 0.0 0.02 0.07 0.2 0.6 1.0",
}
