local gh = require("pack_helpers").gh

vim.pack.add({
  { src = gh("catppuccin/nvim"), name = "catppuccin" },
})

require("catppuccin").setup({
  flavour = "auto",
  background = {
    light = "latte",
    dark = "mocha",
  },
  transparent_background = true,
  show_end_of_buffer = false,
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
    aerial = false,
    barbar = true,
    blink_cmp = true,
    cmp = true,
    gitsigns = true,
    markdown = true,
    render_markdown = true,
    mason = true,
    notify = true,
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
    neotree = false,
    treesitter = true,
  },
})
vim.cmd.colorscheme "catppuccin"

local function detect_background()
  local os_name = vim.uv.os_uname().sysname

  if os_name == "Darwin" and vim.fn.executable("defaults") == 1 then
    local result = vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyle" })
    return vim.v.shell_error == 0 and result:match("Dark") and "dark" or "light"
  end

  if os_name == "Linux" and vim.fn.executable("gsettings") == 1 then
    local color_scheme = vim.fn.system({ "gsettings", "get", "org.gnome.desktop.interface", "color-scheme" })
    if vim.v.shell_error == 0 and color_scheme:match("prefer%-dark") then
      return "dark"
    end

    local gtk_theme = vim.fn.system({ "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme" })
    if vim.v.shell_error == 0 and gtk_theme:lower():match("dark") then
      return "dark"
    end

    return "light"
  end
end

local function refresh_background()
  local mode = detect_background()
  if mode and vim.o.background ~= mode then
    vim.o.background = mode
  end
end

local theme_switch_group = vim.api.nvim_create_augroup("danklinux_theme_switch", { clear = true })

vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
  group = theme_switch_group,
  callback = refresh_background,
})
