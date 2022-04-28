local plug_dir = vim.api.nvim_get_var("plug_dir")


if vim.fn.isdirectory(plug_dir .. '/nvim-cmp') and vim.fn.isdirectory(plug_dir .. '/nvim-autopairs') then
   require("config.nvim_cmp")
end

if vim.fn.isdirectory(plug_dir .. '/nvim-lspconfig') then
  require("config.lsp")
end

if vim.fn.isdirectory(plug_dir .. '/null-ls.nvim') then
  require("config.null_ls")
end

if vim.fn.isdirectory(plug_dir .. '/lualine.nvim') then
  require("config.lualine")
end

if vim.fn.isdirectory(plug_dir .. '/barbar.nvim') then
  require("config.barbar")
end

if vim.fn.isdirectory(plug_dir .. '/nvim-tree.lua') then
  require("config.nvim_tree")
end

if vim.fn.isdirectory(plug_dir .. '/indent-blankline.nvim') then
  require("config.indent_blankline")
end

if vim.fn.isdirectory(plug_dir .. '/Catppuccino.nvim') then
  require("config.colorscheme")
end

if vim.fn.isdirectory(plug_dir .. '/gitsigns.nvim') then
  require("config.gitsigns")
end

if vim.fn.isdirectory(plug_dir .. '/nvim-treesitter') and vim.fn.executable("node") and vim.fn.executable("tree-sitter") then
  require("config.treesitter")
end
