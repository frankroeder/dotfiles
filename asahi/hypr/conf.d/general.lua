hl.config({
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
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    focus_on_activate = true,
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
  },
})

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})
