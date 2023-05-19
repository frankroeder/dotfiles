local util = require "lspconfig/util"

return {
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
