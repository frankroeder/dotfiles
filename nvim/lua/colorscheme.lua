local catppuccino = require("catppuccino")

catppuccino.setup({
  colorscheme = "catppuccino",
  transparency = false,
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
    lsp_trouble = false,
    lsp_saga = false,
    gitgutter = false,
    gitsigns = false,
    telescope = false,
    nvimtree = true,
    which_key = false,
    indent_blankline = false,
    dashboard = false,
    neogit = false,
    vim_sneak = false,
    fern = false,
    barbar = true,
    bufferline = false,
    markdown = false,
  }
})

catppuccino.load()
