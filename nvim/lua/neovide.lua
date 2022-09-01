if not vim.g.neovide then
  return
end

vim.g.gui_font_default_size = 16
vim.g.gui_font_size = vim.g.gui_font_default_size
vim.g.gui_font_face = "Hack Nerd Font"
vim.g.neovide_cursor_animation_length = 0.015
vim.g.neovide_cursor_trail_length = 0.45
vim.g.neovide_cursor_vfx_mode = "torpedo"
vim.g.neovide_input_use_logo = true

RefreshGuiFont = function()
  vim.opt.guifont = string.format("%s:h%s", vim.g.gui_font_face, vim.g.gui_font_size)
end

ResizeGuiFont = function(delta)
  vim.g.gui_font_size = vim.g.gui_font_size + delta
  RefreshGuiFont()
end

ResetGuiFont = function()
  vim.g.gui_font_size = vim.g.gui_font_default_size
  RefreshGuiFont()
end

-- Keymaps
local opts = { noremap = true, silent = true }

vim.keymap.set({ "n", "i" }, "<C-+>", function()
  ResizeGuiFont(1)
end, opts)
vim.keymap.set({ "n", "i" }, "<C-->", function()
  ResizeGuiFont(-1)
end, opts)

vim.env.PATH = vim.env.PATH .. ":" .. os.getenv "HOME" .. "/miniforge3/bin"
vim.g.python3_host_prog = vim.fn.exepath "python"
vim.g.node_host_prog = vim.fn.exepath "node"

-- Call function on startup to set default value
ResetGuiFont()
