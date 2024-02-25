if vim.fn.has "termguicolors" then
  vim.fn.setenv("NVIM_TUI_ENABLE_TRUE_COLOR", 1)
  vim.opt.termguicolors = true
end

local catppuccin = require "catppuccin"

catppuccin.setup {
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
}
vim.cmd [[colorscheme catppuccin]]
