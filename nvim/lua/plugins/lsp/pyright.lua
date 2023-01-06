local general_root = require("plugins.lsp.util").general_root
local util = require "lspconfig/util"
local py_root = { "venv/", "requirements.txt", "setup.py", "pyproject.toml", "setup.cfg" }
local merge_tables = require("utils").merge_tables

return {
  cmd = { vim.fn.exepath "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_dir = function(fname)
    return util.root_pattern(unpack(merge_tables(py_root, general_root)))(fname)
      or util.find_git_ancestor(fname)
      or util.path.dirname(fname)
  end,
  single_file_support = true,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "workspace",
        useLibraryCodeForTypes = true,
      },
    },
  },
}
