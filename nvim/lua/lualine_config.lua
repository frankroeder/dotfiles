local colors = {
  black        = '#393b44',
  white        = '#dfdfe0',
  red          = '#c94f6d',
  green        = '#97c374',
  blue         = '#61afef',
  yellow       = '#dbc074',
  bg           = '#0e171c',
  fg           = '#abb2bf',
  gray         = '#2a2e36',
  gray2        = '#dfdfe0',
  inactivegray = '#526175',
}
custom_color =  {
  normal = {
    a = {bg = colors.bg, fg = colors.fg, gui = 'bold'},
    b = {bg = colors.gray, fg = colors.white},
    c = {bg = colors.gray, fg = colors.fg}
  },
  insert = {a = {bg = colors.blue, fg = colors.black, gui = 'bold'}},
  visual = {a = {bg = colors.yellow, fg = colors.black, gui = 'bold'}},
  replace = {a = {bg = colors.red, fg = colors.black, gui = 'bold'}},
  command = {a = {bg = colors.green, fg = colors.black, gui = 'bold'}},
  inactive = {a = {bg = colors.bg, fg = colors.inactivegray, gui = 'bold'}}
}
require('lualine').setup {
  options = {
    theme = custom_color
  },
  extensions = {'nvim-tree', 'fugitive', 'fzf'}
}
