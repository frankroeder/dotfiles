local table_find_element = require("utils").table_find_element

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

autocmd("BufWritePre", {
  group = augroup("disable undo", { clear = true }),
  desc = "Prevent creation of swap/undo/backup files for specific patterns",
  pattern = { "/tmp/*", "COMMIT_EDITMSG", "MERGE_MSG", "*.tmp", "*.bak", "oil" },
  callback = function()
    vim.opt_local.undofile = false
    vim.opt_local.swapfile = false
    vim.opt_global.backup = false
    vim.opt_global.writebackup = false
  end,
})

autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank {
      higroup = "IncSearch",
      timeout = 300,
      on_visual = true,
    }
  end,
  group = augroup("highlight_yank", { clear = true }),
  desc = "Highlight the yanked region of a document.",
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
  group = augroup("check_time", { clear = true }),
  pattern = "*",
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd "checktime"
    end
  end,
  desc = "Automatically read file changes.",
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

autocmd("VimResized", {
  group = augroup("window_resized", { clear = true }),
  pattern = "*",
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd "tabdo wincmd ="
    vim.cmd("tabnext " .. current_tab)
  end,
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

local status_ok, List = pcall(require, "plenary.collections.py_list")
if not status_ok then
  return
end

vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("last_loc", { clear = true }),
  desc = "Go to last loc when opening a buffer, see ':h last-position-jump'",
  callback = function(event)
    local exclude = { "gitcommit", "commit", "gitrebase", "svn", "hgcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
      return
    end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

local toggle_line_numbers_group = augroup("toggle_line_numbers", { clear = true })
local line_numbers_ft_ignore_list = List { "Telescope" }
autocmd({ "FocusGained", "InsertLeave" }, {
  pattern = "*",
  callback = function()
    if line_numbers_ft_ignore_list:contains(vim.bo.filetype) or vim.bo.filetype == "" then
      return
    end
    vim.cmd [[set relativenumber]]
  end,
  group = toggle_line_numbers_group,
  desc = "Show relative line numbers in normal mode or on focus.",
})
autocmd({ "FocusLost", "InsertEnter" }, {
  pattern = "*",
  callback = function()
    if line_numbers_ft_ignore_list:contains(vim.bo.filetype) or vim.bo.filetype == "" then
      return
    end
    vim.cmd [[set norelativenumber]]
  end,
  group = toggle_line_numbers_group,
  desc = "Show line numbers in insert mode or on losing focus.",
})
