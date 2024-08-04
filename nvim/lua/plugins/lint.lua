return {
  "mfussenegger/nvim-lint",
  config = function()
    require("lint").linters_by_ft = {
      c = { "clangtidy" },
      javascript = { "eslint" },
      typescript = { "eslint" },
    }
  end,
  init = function()
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      callback = function()
        require("lint").try_lint()
      end,
    })
  end,
}
