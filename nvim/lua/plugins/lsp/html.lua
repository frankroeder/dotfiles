local util = require "lspconfig/util"

return {
  cmd = { vim.fn.exepath "html-languageserver", "--stdio" },
  filetypes = { "html" },
  root_dir = function(fname)
    return util.find_git_ancestor(fname) or util.path.dirname(fname)
  end,
  init_options = {
    configurationSection = { "html", "css", "javascript" },
    embeddedLanguages = {
      css = true,
      javascript = true,
    },
  },
}
