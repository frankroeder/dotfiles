local gh = require("pack_helpers").gh

vim.pack.add({
  gh("kylechui/nvim-surround"),
})

require("nvim-surround").setup({})
