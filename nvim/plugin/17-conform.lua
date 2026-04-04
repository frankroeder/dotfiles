local gh = require("pack_helpers").gh

vim.pack.add({
  gh("stevearc/conform.nvim"),
})

require("conform").setup({
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
    json = { "jq" },
  },
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.keymap.set({ "n", "v" }, "<Space>cf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "[c]ode [f]ormat" })
