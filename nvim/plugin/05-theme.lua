local gh = require("pack_helpers").gh

vim.pack.add({
  { src = gh("catppuccin/nvim"), name = "catppuccin" },
})

require("catppuccin").setup({
  background = { light = "latte", dark = "mocha" },
  transparent_background = true,
  integrations = {
    blink_cmp = true,
    gitsigns = true,
    markdown = true,
    native_lsp = { enabled = true, inlay_hints = { background = true } },
    render_markdown = true,
    treesitter = true,
  },
})

local function set_theme(background)
  vim.o.background = background
  vim.cmd.colorscheme(background == "light" and "catppuccin-latte" or "catppuccin-mocha")
end

vim.api.nvim_create_user_command("ThemeLight", function()
  set_theme "light"
end, {})

vim.api.nvim_create_user_command("ThemeDark", function()
  set_theme "dark"
end, {})

vim.api.nvim_create_user_command("ThemeToggle", function()
  set_theme(vim.o.background == "dark" and "light" or "dark")
end, {})

set_theme(vim.o.background == "light" and "light" or "dark")
