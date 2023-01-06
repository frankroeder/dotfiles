local table_find_element = require("utils").table_find_element

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local yank_group = augroup("yank_group", { clear = true })
autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank {
      higroup = "IncSearch",
      timeout = 300,
      on_visual = true,
    }
  end,
  group = yank_group,
  desc = "Highlight the yanked region of a document.",
})

autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "Go to last loc when opening a buffer",
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

local trim_group = augroup("trim_group", { clear = true })
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
autocmd({ "FileType" }, {
  pattern = {
    "qf",
    "help",
    "man",
    "notify",
    "lspinfo",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "PlenaryTestPopup",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
  desc = "Close certain filetypes with <q>",
})
