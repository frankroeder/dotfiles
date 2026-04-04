local gh = require("pack_helpers").gh

vim.pack.add({
  gh("nvim-lua/plenary.nvim"),
  gh("MunifTanjim/nui.nvim"),
  gh("kawre/leetcode.nvim"),
})

require("leetcode").setup({
  lang = "python",
})
