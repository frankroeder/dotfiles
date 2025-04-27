local utils = require "utils"

---@type vim.lsp.Config
return {
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = utils.root_markers["python"],
  settings = {
    basedpyright = {
      disableOrganizeImports = true,
      analysis = {
        ignore = { "*" }, -- using ruff
        typeCheckingMode = "basic", -- off, basic, standard, strict, all
        autoImportCompletions = true,
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticsMode = "openFilesOnly", -- workspace, openFilesOnly
        diagnosticSeverityOverrides = {
          reportUnusedImports = false,
          reportUnusedVariable = false,
        },
      },
    },
  },
  single_file_support = true,
}
