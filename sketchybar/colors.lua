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
  pill_bg = 0xff313244,
  bar_color = 0x00000000,
  bar_border_color = 0x00000000,
  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then
      return color
    end
    return bit.bor(bit.band(color, 0x00ffffff), bit.lshift(math.floor(alpha * 255.0), 24))
  end,
}
