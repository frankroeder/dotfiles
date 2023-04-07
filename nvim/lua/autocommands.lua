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

local status_ok, List = pcall(require, "plenary.collections.py_list")
if not status_ok then
  return
end

local last_place = augroup("last_place", { clear = true })
autocmd({ "BufWinEnter", "FileType" }, {
  group = last_place,
  desc = "Go to last loc when opening a buffer",
  callback = function()
    local bt_ignore_list = List { "quickfix", "nofile", "help" }
    -- Check if the buffer should be ignored
    if bt_ignore_list:contains(vim.bo.buftype) then
      return
    end
    local ft_ignore_list = List { "gitcommit", "gitrebase", "svn", "hgcommit" }

    -- Check if the filetype should be ignored
    if ft_ignore_list:contains(vim.bo.filetype) then
      -- reset cursor to first line
      vim.cmd [[normal! gg]]
      return
    end

    -- If a line has already been specified on the command line, we are done
    --   nvim file +num
    if vim.fn.line "." > 1 then
      return
    end

    local last_line = vim.fn.line [['"]]
    local buff_last_line = vim.fn.line "$"
    local window_last_line = vim.fn.line "w$"
    local window_first_line = vim.fn.line "w0"
    -- If the last line is set and the less than the last line in the buffer
    if last_line > 0 and last_line <= buff_last_line then
      -- Check if the last line of the buffer is the same as the window
      if window_last_line == buff_last_line then
        -- Set line to last line edited
        vim.cmd [[normal! g`"]]
        -- Try to center
      elseif buff_last_line - last_line > ((window_last_line - window_first_line) / 2) - 1 then
        vim.cmd [[normal! g`"zz]]
      else
        vim.cmd [[normal! G'"<c-e>]]
      end
    end
    -- open fold
    if vim.fn.foldclosed "." ~= -1 then
      vim.cmd [[normal! zvzz]]
    end
  end,
})
augroup("toggle_line_numbers", { clear = true })
autocmd({ "FocusGained", "InsertLeave" }, {
  pattern = "*",
  callback = function()
    local ft_ignore_list = List { "NvimTree" }
    if ft_ignore_list:contains(vim.bo.filetype) then
      return
    end
    vim.cmd [[set relativenumber]]
  end,
  group = "toggle_line_numbers",
  desc = "Show relative line numbers in normal mode or on focus.",
})
autocmd({ "FocusLost", "InsertEnter" }, {
  pattern = "*",
  callback = function()
    local ft_ignore_list = List { "NvimTree" }
    if ft_ignore_list:contains(vim.bo.filetype) then
      return
    end
    vim.cmd [[set norelativenumber]]
  end,
  group = "toggle_line_numbers",
  desc = "Show line numbers in insert mode or on losing focus.",
})
