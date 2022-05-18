vim.api.nvim_create_augroup("packer_user_config", {clear = true})
vim.api.nvim_create_autocmd("BufWritePost", {
  group = "packer_user_config",
  pattern = "plugins.lua",
  callback = function ()
    vim.cmd("source <afile> | PackerCompile")
  end,
})

-- highlight yanks
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank(
      { higroup="IncSearch", timeout=300, on_visual=true }
    )
  end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = '*.snippets',
  command = "CmpUltisnipsReloadSnippets",
})

-- toggle line numbers
vim.api.nvim_create_augroup("toggle_line_numbers", {clear = true})
vim.api.nvim_create_autocmd({"FocusGained", "InsertLeave"}, {
  pattern = '*',
  command = "set relativenumber",
  group = "toggle_line_numbers"
})
vim.api.nvim_create_autocmd({"FocusLost", "InsertEnter"}, {
  pattern = '*',
  command = "set norelativenumber",
  group = "toggle_line_numbers"
})

-- toggle color of column
vim.api.nvim_create_augroup("toggle_color_column", {clear = true})
vim.api.nvim_create_autocmd({"BufEnter", "FocusGained", "InsertLeave"}, {
  pattern = '*',
  command = "set cc=",
  group = "toggle_color_column"
})
vim.api.nvim_create_autocmd({"BufLeave", "FocusLost", "InsertEnter"}, {
  pattern = '*',
  command = "set cc=81",
  group = "toggle_color_column"
})

-- detect file change
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  pattern = '*',
  command = [[echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None]],
})

-- auto read
vim.api.nvim_create_autocmd({"FocusGained", "BufEnter", "CursorHold", "CursorHoldI"}, {
  pattern = '*',
  command = [[if mode() != 'c' | checktime | endif]],
})

-- automatically close the tab/vim when nvim-tree is the last window
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = '*',
  command = "if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif",
  nested = true,
})

-- trim whitespaces
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  command = [[if index(["markdown"], &ft) < 0 | :call StripTrailingWhitespaces()]],
})
