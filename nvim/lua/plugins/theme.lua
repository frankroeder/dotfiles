return {
  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    opts = {
      compile = false,
      theme = "wave",
      background = {
        dark = "wave",
        light = "lotus",
      },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      background = { -- :h background
        light = "latte",
        dark = "mocha",
      },
      transparent_background = true,
      show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
      term_colors = false,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = { "italic" },
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
      integrations = {
        barbar = true,
        cmp = true,
        gitsigns = true,
        indent_blankline = {
          enabled = true,
          colored_indent_levels = false,
        },
        markdown = true,
        mason = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
          inlay_hints = {
            background = true,
          },
        },
        neotree = {
          enabled = true,
          show_root = false,
          transparent_panel = false,
        },
        treesitter = true,
      },
    },
  },
}
