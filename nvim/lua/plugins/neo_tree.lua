return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  opts = {
    close_if_last_window = true,
    enable_diagnostics = false,
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_by_name = {
          "node_modules",
          "__pycache__",
          ".git",
        },
        hide_by_pattern = {
          "*.cache",
          "*.egg-info",
        },
        never_show = {
          ".DS_Store",
        },
      },
    },
  },
  keys = {
    { [[<Leader>n]], ":Neotree toggle reveal<CR>", desc = "Toggle Neotree" },
  },
}
