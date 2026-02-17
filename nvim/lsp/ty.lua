local utils = require "utils"

---@type vim.lsp.Config
return {
  cmd = { "ty", "server" },
  filetypes = { "python" },
  root_markers = utils.merge_tables(utils.root_markers["python"], { "ty.toml" }),
  init_options = {
    settings = {
      logLevel = "info",
      logFile = vim.fn.stdpath "log" .. "/lsp.ty.log",
      experimental = {
        completions = { enable = true },
      },
    },
  },
  single_file_support = true,
}
