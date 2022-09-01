local table_find_element = require("utils").table_find_element

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local packer_group = augroup("packer_user_config", { clear = true })

autocmd("BufWritePost", {
  group = packer_group,
  pattern = "plugins.lua",
  callback = function()
    vim.cmd "source <afile> | PackerCompile"
  end,
  desc = "Automatically recompile packer when editing plugin config.",
})

autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank {
      higroup = "IncSearch",
      timeout = 300,
      on_visual = true,
    }
  end,
  desc = "Highlight the yanked region of a document.",
})

autocmd("BufWritePost", {
  pattern = "*.snippets",
  command = "CmpUltisnipsReloadSnippets",
  desc = "Reload ultisnips when saving a snippets file.",
})

augroup("toggle_line_numbers", { clear = true })
autocmd({ "FocusGained", "InsertLeave" }, {
  pattern = "*",
  command = "set relativenumber",
  group = "toggle_line_numbers",
  desc = "Show relative line numbers in normal mode or on focus.",
})
autocmd({ "FocusLost", "InsertEnter" }, {
  pattern = "*",
  command = "set norelativenumber",
  group = "toggle_line_numbers",
  desc = "Show line numbers in insert mode or on losing focus.",
})

augroup("toggle_color_column", { clear = true })
autocmd({ "BufEnter", "FocusGained", "InsertLeave" }, {
  pattern = "*",
  command = "set cc=",
  group = "toggle_color_column",
})
autocmd({ "BufLeave", "FocusLost", "InsertEnter" }, {
  pattern = "*",
  command = "set cc=81",
  group = "toggle_color_column",
  desc = "Show a colored column for the 80 character boundary.",
})

autocmd("FileChangedShellPost", {
  pattern = "*",
  command = [[echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None]],
  desc = "Detect file change on disk.",
})

autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  command = [[if mode() != 'c' | checktime | endif]],
  desc = "Automatically read file changes.",
})

autocmd("BufEnter", {
  pattern = "*",
  command = "if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif",
  nested = true,
  desc = "Automatically close the tab/vim when nvim-tree is the last window.",
})

local trim_group = augroup("packer_user_config", { clear = true })

local trim = function(pattern)
  local save = vim.fn.winsaveview()
  vim.cmd(string.format("keepjumps keeppatterns silent! %s", pattern))
  vim.fn.winrestview(save)
end

autocmd("BufWritePre", {
  pattern = "*",
  group = trim_group,
  callback = function()
    if not table_find_element({ "markdown" }, vim.bo.filetype) then
      local save = vim.fn.winsaveview()
      trim [[%s/\s\+$//e]]
      vim.fn.winrestview(save)
    end
  end,
  desc = "Automatically trim trailing whitespaces on write.",
})

autocmd("BufWritePre", {
  pattern = "*",
  group = trim_group,
  callback = function()
    local save = vim.fn.winsaveview()
    trim [[%s/\($\n\s*\)\+\%$//]]
    vim.fn.winrestview(save)
  end,
  desc = "Automatically trim trailing lines on write.",
})

local win_group = augroup("window_resized", { clear = true })
autocmd("VimResized", {
  group = win_group,
  pattern = "*",
  command = "wincmd =",
  desc = "Automatically resize windows when the host window size changes.",
})
