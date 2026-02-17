local utils = require "utils"

---@type vim.lsp.Config
return {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = utils.root_markers["python"],
  init_options = {
    settings = {
      organizeImports = true,
      lineLength = 100,
      showSyntaxErrors = true,
      logLevel = "info",
      fixAll = true,
      codeAction = {
        lint = {
          enable = true,
          preview = true,
        },
      },
      lint = {
        select = {
          "E",
          "F",
          "UP",
          "B",
          "SIM",
          "C4",
          "FIX",
          "RET",
          "PD",
          "PL",
          "UP",
          "RUF",
        },
        -- select = { "ALL" },
      },
    },
  },
}
