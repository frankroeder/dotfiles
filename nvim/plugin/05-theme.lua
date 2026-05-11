local gh = require("pack_helpers").gh

local function system_background()
  local sysname = (vim.uv or vim.loop).os_uname().sysname

  if sysname == "Darwin" and vim.fn.executable("defaults") == 1 then
    local result = vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyle" })
    return vim.v.shell_error == 0 and result:match("Dark") and "dark" or "light"
  end

  if sysname == "Linux" and vim.fn.executable("gsettings") == 1 then
    local color_scheme = vim.fn.system({ "gsettings", "get", "org.gnome.desktop.interface", "color-scheme" })
    if vim.v.shell_error == 0 and color_scheme:match("prefer%-dark") then
      return "dark"
    end
    if vim.v.shell_error == 0 and color_scheme:match("prefer%-light") then
      return "light"
    end

    local gtk_theme = vim.fn.system({ "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme" })
    if vim.v.shell_error == 0 and gtk_theme:lower():match("dark") then
      return "dark"
    end

    return "light"
  end

  return vim.o.background == "light" and "light" or "dark"
end

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

local function refresh_theme()
  set_theme(system_background())
end

refresh_theme()

vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
  group = vim.api.nvim_create_augroup("adaptive_theme", { clear = true }),
  callback = refresh_theme,
})
