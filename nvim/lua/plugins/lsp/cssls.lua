local util = require "lspconfig/util"

return {
  cmd = { vim.fn.exepath "css-languageserver", "--stdio" },
  filetypes = { "css", "scss", "sass", "less" },
  root_dir = function(fname)
    return util.find_git_ancestor(fname) or vim.fn.getcwd()
  end,
  settings = {
    css = {
      validate = true,
    },
    less = {
      validate = true,
    },
    scss = {
      validate = true,
    },
  },
}
