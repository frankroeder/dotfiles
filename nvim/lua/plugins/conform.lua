local M = {
  "stevearc/conform.nvim",
  event = "BufEnter",
}
M.config = function()
  local conform = require "conform"
  conform.formatters.jq = { args = { "--indent", "4" } }
  conform.setup {
    formatters_by_ft = {
      c = { "clang-tidy", "clang-format" },
      cpp = { "clang-tidy", "clang-format" },
      go = { "goimports", "gofmt" },
      lua = { "stylua" },
      python = { "isort", "ruff" },
      json = { "jq" },
    },
  }
  vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
end

M.keys = function()
  return {
    {
      "<Space>cf",
      function()
        require("conform").format { async = true, lsp_format = "fallback" }
      end,
      mode = { "n", "v" },
      desc = "[c]ode [f]ormat",
    },
  }
end

return M
