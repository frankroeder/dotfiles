local catppuccino = require("catppuccino")

catppuccino.setup({
  colorscheme = "catppuccino",
  transparency = true,
  styles = {
    comments = "italic",
    functions = "italic",
    keywords = "italic",
    strings = "NONE",
    variables = "NONE",
  },
  integrations = {
    treesitter = true,
    native_lsp = {
      enabled = true,
      styles = {
        errors = "italic",
        hints = "italic",
        warnings = "italic",
        information = "italic"
      }
    },
    gitsigns = true,
    nvimtree = {
      enabled = false,
      show_root = false,
    },
    indent_blankline = true,
    barbar = true,
    markdown = true,

    lsp_trouble = false,
    lsp_saga = false,
    telescope = false,
    gitgutter = false,
    which_key = false,
    vim_sneak = false,
    neogit = false,
    dashboard = false,
    fern = false,
    bufferline = false,
  }
})

catppuccino.load()
