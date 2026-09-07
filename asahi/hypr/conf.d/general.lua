hl.config {
  general = {
    gaps_in = 4,
    gaps_out = 10,
    float_gaps = 6,
    border_size = 2,
    resize_on_border = true,
    extend_border_grab_area = 30,
    ["col.active_border"] = { colors = { "rgb(89b4fa)", "rgb(cba6f7)" }, angle = 45 },
    ["col.inactive_border"] = "rgb(45475a)",
    layout = "dwindle",
  },

  decoration = {
    rounding = 10,
    active_opacity = 1.0,
    inactive_opacity = 0.9,

    shadow = {
      enabled = false,
    },

    blur = {
      enabled = true,
      size = 8,
      passes = 2,
      noise = 0.0117,
      vibrancy = 0.1696,
    },
  },

  dwindle = {
    preserve_split = true,
    -- New windows always open right/below instead of following the mouse
    -- quadrant, so where a split lands stops depending on cursor position.
    force_split = 2,
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_scale_notification = true,
    focus_on_activate = true,
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
    -- Lets a fresh hyprlock re-acquire the session lock if the previous one
    -- died. Without it a crashed locker leaves the session stuck rather than
    -- recoverable — worth having when hyprlock is the only screen gate.
    allow_session_lock_restore = true,
    -- Focusing a window underneath a fullscreen one un-fullscreens rather
    -- than focusing something invisible.
    on_focus_under_fullscreen = 1,
    -- Do not follow an app to whatever workspace it was launched from.
    initial_workspace_tracking = 0,
    -- Three missed pings before the "not responding" treatment; one is too
    -- eager on this GPU, where a stall during a mode-set is normal.
    anr_missed_pings = 3,
  },

  binds = {
    -- Leaving a workspace hides the scratchpad (SUPER+S) instead of letting
    -- it trail along onto the next one.
    hide_special_on_workspace_change = true,
  },

  cursor = {
    -- no_hardware_cursors lives in asahi.lua; these two are taste, not Asahi.
    hide_on_key_press = true,
    warp_on_change_workspace = 1,
  },

  -- SUPER+W groups windows into tabs. Without this block the groupbar renders
  -- in Hyprland's stock colors and clashes with the Catppuccin borders above.
  group = {
    col = {
      border_active = { colors = { "rgb(89b4fa)", "rgb(cba6f7)" }, angle = 45 },
      border_inactive = "rgb(45475a)",
      border_locked_active = { colors = { "rgb(f9e2af)", "rgb(fab387)" }, angle = 45 },
      border_locked_inactive = "rgb(45475a)",
    },

    groupbar = {
      font_family = "JetBrainsMono Nerd Font",
      font_size = 11,
      font_weight_active = "bold",
      font_weight_inactive = "normal",
      height = 20,
      indicator_height = 2,
      indicator_gap = 4,
      gaps_in = 4,
      gaps_out = 0,
      text_color = "rgb(cdd6f4)",
      text_color_inactive = "rgba(cdd6f490)",
      col = {
        active = "rgba(1e1e2edd)",
        inactive = "rgba(1e1e2e88)",
      },
      gradients = true,
      gradient_rounding = 6,
    },
  },
  -- Asahi note: blur + animations tuned; test perf on Apple GPU (reverse-eng driver limits, aquamarine history)
}

hl.gesture {
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
}
