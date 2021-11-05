local keymap = require 'utils'.keymap

-- global options in nvim-tree-options should be done BEFORE the setup call
vim.g.nvim_tree_gitignore = 1

require'nvim-tree'.setup {
  -- disables netrw completely
  disable_netrw = false,
  -- open the tree when running this setup function
  open_on_setup = false,
   -- closes neovim automatically when the tree is the last **WINDOW** in the view
  auto_close = true,
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
    custom = { '.git', '.cache', '.vim', '__pycache__', 'node_modules', '.egg-info' }
  }
}

keymap("n", "<Leader>n", ":NvimTreeToggle<CR>")
