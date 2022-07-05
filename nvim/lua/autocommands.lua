local packer_group = vim.api.nvim_create_augroup("packer_user_config", {clear = true})
vim.api.nvim_create_autocmd("BufWritePost", {
  group = packer_group,
  pattern = "plugins.lua",
  callback = function ()
    vim.cmd("source <afile> | PackerCompile")
  end,
  desc = 'Automatically recompile packer when editing plugin config.'
})

vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank(
      { higroup="IncSearch", timeout=300, on_visual=true }
    )
  end,
  desc = 'Highlight the yanked region of a document.'
})

vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = '*.snippets',
  command = "CmpUltisnipsReloadSnippets",
  desc = "Reload ultisnips when saving a snippets file."
})

vim.api.nvim_create_augroup("toggle_line_numbers", {clear = true})
vim.api.nvim_create_autocmd({"FocusGained", "InsertLeave"}, {
  pattern = '*',
  command = "set relativenumber",
  group = "toggle_line_numbers",
  desc = "Show relative line numbers in normal mode or on focus."
})
vim.api.nvim_create_autocmd({"FocusLost", "InsertEnter"}, {
  pattern = '*',
  command = "set norelativenumber",
  group = "toggle_line_numbers",
  desc = "Show line numbers in insert mode or on losing focus."
})

vim.api.nvim_create_augroup("toggle_color_column", {clear = true})
vim.api.nvim_create_autocmd({"BufEnter", "FocusGained", "InsertLeave"}, {
  pattern = '*',
  command = "set cc=",
  group = "toggle_color_column"
})
vim.api.nvim_create_autocmd({"BufLeave", "FocusLost", "InsertEnter"}, {
  pattern = '*',
  command = "set cc=81",
  group = "toggle_color_column",
  desc = "Show a colored column for the 80 character boundary."
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  pattern = '*',
  command = [[echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None]],
  desc = 'Detect file change on disk.'
})

vim.api.nvim_create_autocmd({"FocusGained", "BufEnter", "CursorHold", "CursorHoldI"}, {
  pattern = '*',
  command = [[if mode() != 'c' | checktime | endif]],
  desc = 'Automatically read file changes.'
})

vim.api.nvim_create_autocmd('BufEnter', {
  pattern = '*',
  command = "if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif",
  nested = true,
  desc = 'Automatically close the tab/vim when nvim-tree is the last window.'
})

vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  command = [[if index(["markdown"], &ft) < 0 | :call StripTrailingWhitespaces()]],
  desc = 'Automatically trim whitespaces on write.'
})

local win_group = vim.api.nvim_create_augroup('window_resized', { clear = true })
vim.api.nvim_create_autocmd('VimResized', {
  group = win_group,
  pattern = '*',
  command = 'wincmd =',
  desc = 'Automatically resize windows when the host window size changes.'
})

