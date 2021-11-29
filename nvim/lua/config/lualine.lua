local colors = {
  black        = '#393b44',
  red          = '#c94f6d',
  green        = '#97c374',
  yellow       = '#dbc074',
  blue         = '#61afef',
  magenta      = '#c678dd',
  cyan         = '#63cdcf',
  white        = '#dfdfe0',
  fg           = '#abb2bf',
  bg           = '#0e171c',
  text         = '#0e171c',
  cursor       = '#abb2bf'
}
custom_color =  {
  normal = {
    a = {bg = colors.blue, fg = colors.bg, gui = 'bold'},
    b = {bg = colors.black, fg = colors.fg},
    c = {bg = colors.bg, fg = colors.fg}
  },
  insert = {a = {bg = colors.yellow, fg = colors.text, gui = 'bold'}},
  visual = {a = {bg = colors.magenta, fg = colors.text, gui = 'bold'}},
  replace = {a = {bg = colors.red, fg = colors.text, gui = 'bold'}},
  command = {a = {bg = colors.green, fg = colors.text, gui = 'bold'}},
  inactive = {a = {bg = colors.bg, fg = colors.inactivegray, gui = 'bold'}}
}

require('lualine').setup {
  options = {
    theme = custom_color,
    disabled_filetypes = {'help'}
  },
  extensions = {'nvim-tree', 'fzf'},
}
