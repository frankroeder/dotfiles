local keymap  = require 'utils'.keymap
local buf_keymap = require 'utils'.buf_keymap

vim.g.vista_sidebar_width = 35
vim.g.vista_echo_cursor_strategy = 'echo'
vim.g.vista_close_on_fzf_select = 1

vim.g.vista_default_executive = 'nvim_lsp'
vim.g.vista_disable_statusline = 0

keymap("n", "<Leader>v", [[:Vista!!<CR>]])
keymap("n", "<Leader>p", [[:Vista finder<CR>]])

vim.api.nvim_create_augroup("VistaMapping", {clear = true})
vim.api.nvim_create_autocmd("FileType ", {
  group = "VistaMapping",
  pattern = { "vista", "vista_kind" },
  callback = function ()
		buf_keymap(0, "n", "/", [[:<c-u>call vista#finder#fzf#Run()<CR>]])
  end,
})
