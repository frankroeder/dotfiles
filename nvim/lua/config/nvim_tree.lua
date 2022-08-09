local keymap = require 'utils'.keymap

local status_ok, nvim_tree = pcall(require, 'nvim-tree')
if not status_ok then
  return
end

nvim_tree.setup {
  -- disables netrw completely
  disable_netrw = false,
  -- open the tree when running this setup function
  open_on_setup = false,
   -- show lsp diagnostics in the signcolumn
  diagnostics = {
    enable = false,
    icons = {
      hint = "",
      info = "",
      warning = "",
      error = "",
    }
  },
  filters = {
    custom = { '.git', '.cache', '.vim', '__pycache__', 'node_modules', '.egg-info' , '.gitignore' }
  }
}

keymap("n", "<Leader>n", ":NvimTreeToggle<CR>")
