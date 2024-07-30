return {
  "stevearc/aerial.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    backends = { "treesitter", "lsp", "markdown", "man" },
    default_direction = "prefer_right",
    ignore = {
      filetypes = { "tex" },
    },
  },
  keys = {
    { "<Leader>a", "<cmd>AerialToggle!<CR>", mode = "n" },
    { "<Leader>p", [[<cmd>call aerial#fzf()<CR>]], mode = "n" },
  },
}
