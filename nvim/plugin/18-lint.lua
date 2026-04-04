local gh = require("pack_helpers").gh

vim.pack.add({
  gh("mfussenegger/nvim-lint"),
})

require("lint").linters_by_ft = {
  c = { "clangtidy" },
  javascript = { "eslint" },
  typescript = { "eslint" },
}

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
  group = vim.api.nvim_create_augroup("nvim_lint_autorun", { clear = true }),
  callback = function()
    require("lint").try_lint()
  end,
})
