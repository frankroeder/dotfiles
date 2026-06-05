return {
  black = 0xff11111b,
  white = 0xffcdd6f4,
  red = 0xfff38ba8,
  green = 0xffa6e3a1,
  blue = 0xff89b4fa,
  yellow = 0xfff9e2af,
  orange = 0xfffab387,
  magenta = 0xfff5c2e7,
  purple = 0xffcba6f7,
  grey = 0xff9399b2,
  dirty_white = 0xffbac2de,
  lightblack = 0xff313244,
  transparent = 0x00000000,

  crust = 0xff11111b,
  mantle = 0xff181825,
  base = 0xff1e1e2e,
  surface0 = 0xff313244,
  surface1 = 0xff45475a,
  surface2 = 0xff585b70,
  overlay0 = 0xff6c7086,
  overlay1 = 0xff7f849c,
  overlay2 = 0xff9399b2,
  subtext0 = 0xffa6adc8,
  subtext1 = 0xffbac2de,
  rosewater = 0xfff5e0dc,
  flamingo = 0xfff2cdcd,
  pink = 0xfff5c2e7,
  mauve = 0xffcba6f7,
  maroon = 0xffeba0ac,
  peach = 0xfffab387,
  teal = 0xff94e2d5,
  sky = 0xff89dceb,
  sapphire = 0xff74c7ec,
  lavender = 0xffb4befe,

  bar = {
    bg = 0xff181825,
    border = 0xff45475a,
  },
  popup = {
    bg = 0xff1e1e2e,
    border = 0xffcba6f7,
  },
  bg = 0xff1e1e2e,
  bg1 = 0xff181825,
  bg2 = 0xff11111b,
  bg3 = 0xff45475a,
  pill_bg = 0xff313244,
  bar_color = 0x00000000,
  bar_border_color = 0x00000000,
  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then
      return color
    end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
