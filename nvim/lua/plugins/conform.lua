return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    formatters = {
      jq = {
        args = { "--indent", "4" },
      },
    },
    formatters_by_ft = {
      c = { "clang-tidy", "clang-format" },
      cpp = { "clang-tidy", "clang-format" },
      go = { "goimports", "gofmt" },
      lua = { "stylua" },
      python = { "isort", "ruff" },
      json = { "jq" },
    },
  },
  keys = {
    {
      "<Space>cf",
      function()
        require("conform").format { async = true, lsp_format = "fallback" }
      end,
      mode = { "n", "v" },
      desc = "[c]ode [f]ormat",
    },
  },
  init = function()
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
