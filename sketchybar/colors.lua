return {
  black = 0xff15161e,
  white = 0xffc0caf5,
  red = 0xfff7768e,
  green = 0xff9ece6a,
  blue = 0xff7aa2f7,
  yellow = 0xffe0af68,
  orange = 0xffe0af68,
  magenta = 0xffbb9af7,
  purple = 0xffbb9af7,
  grey = 0xffa9b1d6,
  dirty_white = 0xffc0caf5,
  lightblack = 0xff414868,
  transparent = 0x00000000,

  crust = 0xff15161e,
  mantle = 0xff1a1b26,
  base = 0xff1a1b26,
  surface0 = 0xff414868,
  surface1 = 0xff414868,
  surface2 = 0xff5a5f7a,
  overlay0 = 0xff6b7089,
  overlay1 = 0xff7f849c,
  overlay2 = 0xffa9b1d6,
  subtext0 = 0xffa9b1d6,
  subtext1 = 0xffc0caf5,
  rosewater = 0xffc0caf5,
  flamingo = 0xfff7768e,
  pink = 0xffbb9af7,
  mauve = 0xffbb9af7,
  maroon = 0xfff7768e,
  peach = 0xffe0af68,
  teal = 0xff7dcfff,
  sky = 0xff89dceb,
  sapphire = 0xff7aa2f7,
  lavender = 0xffc0caf5,

  bar = {
    bg = 0xff1a1b26,
    border = 0xff414868,
  },
  popup = {
    bg = 0xff1a1b26,
    border = 0xff7aa2f7,
  },
  bg = 0xff1a1b26,
  bg1 = 0xff15161e,
  bg2 = 0xff15161e,
  bg3 = 0xff414868,
  pill_bg = 0xff414868,
  bar_color = 0x00000000,
  bar_border_color = 0x00000000,
  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then
      return color
    end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
