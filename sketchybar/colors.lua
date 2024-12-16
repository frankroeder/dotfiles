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
  try = 0xff11111b,
  try2 = 0xff181825,
  try3 = 0xff1e1e2e,
  try_border = 0xff585b70,
  try4 = 0xff1e1e2e,

  bar = {
    bg = 0xf111111b,
    border = 0xff45475a,
  },
  popup = {
    bg = 0xc045475a,
    border = 0xffcba6f7,
  },
  bg1 = 0xd3181825,
  bg2 = 0xff11111b,
  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then
      return color
    end
    return bit.bor(bit.band(color, 0x00ffffff), bit.lshift(math.floor(alpha * 255.0), 24))
  end,
}
