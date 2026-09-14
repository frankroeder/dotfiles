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

    -- libinput default. The MTP custom curve below ignores this; 0 keeps any other pointer at stock speed.
    sensitivity = 0,
  },

  -- Commit a workspace swipe after 25% travel.
  gestures = {
    workspace_swipe_cancel_ratio = 0.25,
  },
}

-- Built-in Asahi MTP pad (Intel Macs are apple-spi-trackpad). Stock macOS tracking
-- speed (default slider, com.apple.mouse.scaling 0.6875): modest low-speed gain
-- (slow drags match macOS, not a crawl), then a damped high-speed ramp.
-- "<step> <output velocity per step>" — raise later points to speed up flicks,
-- earlier points for slow drags. Keep this rule even on a stock profile: hyprctl
-- reload does not reset a device, it only stops overriding it.
hl.device {
  name = "apple-mtp-multi-touch",
  accel_profile = "custom 1.0 0.0 0.10 0.22 0.38 0.58 0.86",
  scroll_points = "1.0 0.0 0.02 0.07 0.2 0.6 1.0",
}
