local general_root = require("plugins.lsp.util").general_root
local util = require "lspconfig/util"
local py_root = { "venv/", "requirements.txt", "setup.py", "pyproject.toml", "setup.cfg" }
local merge_tables = require("utils").merge_tables

return {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_dir = function(fname)
    return util.root_pattern(unpack(merge_tables(py_root, general_root)))(fname)
      or util.find_git_ancestor(fname)
      or util.path.dirname(fname)
  end,
  handlers = {
    ["textDocument/publishDiagnostics"] = function() end,
  },
  single_file_support = true,
  settings = {
    pyright = {
      disableOrganizeImports = true,
    },
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "workspace",
        useLibraryCodeForTypes = true,
      },
    },
  },
}
