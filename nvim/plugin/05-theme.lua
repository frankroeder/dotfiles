local gh = require("pack_helpers").gh
local utils = require "utils"

local os_name = utils.os_name()
local dankcolors_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"

local function system_background()
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

local function load_dankcolors()
  local ok, spec = pcall(dofile, dankcolors_path)
  local plugin = ok and type(spec) == "table" and spec[1]
  if type(plugin) ~= "table" or type(plugin.config) ~= "function" then
    vim.notify("Failed to load DMS Neovim theme", vim.log.levels.WARN)
    return false
  end

  local configured, err = pcall(plugin.config)
  if not configured then
    vim.notify(("Failed to apply DMS Neovim theme: %s"):format(err), vim.log.levels.WARN)
    return false
  end

  vim.g.dankcolors_active = true
  vim.api.nvim_exec_autocmds("User", { pattern = "DankcolorsReloaded", modeline = false })
  return true
end

local function watch_dankcolors()
  if _G._dankcolors_signal then
    return
  end

  local uv = vim.uv or vim.loop
  _G._dankcolors_signal = uv.new_signal()
  _G._dankcolors_signal:start("sigusr1", vim.schedule_wrap(function()
    if load_dankcolors() then
      vim.notify("DMS theme reloaded", vim.log.levels.INFO)
    end
  end))
end

local function setup_catppuccin()
  vim.g.dankcolors_active = false

  local background = system_background()
  if background then
    vim.o.background = background
  end

  vim.pack.add({
    { src = gh("catppuccin/nvim"), name = "catppuccin" },
  })

  require("catppuccin").setup({
    flavour = "auto",
    background = { light = "latte", dark = "mocha" },
    transparent_background = true,
    show_end_of_buffer = false,
    term_colors = false,
    styles = {
      comments = { "italic" },
      conditionals = { "italic" },
      variables = { "italic" },
    },
    integrations = {
      blink_cmp = true,
      cmp = true,
      gitsigns = true,
      markdown = true,
      mason = true,
      native_lsp = { enabled = true, inlay_hints = { background = true } },
      notify = true,
      render_markdown = true,
      treesitter = true,
    },
  })
  vim.cmd.colorscheme "catppuccin"
end

local function refresh_theme()
  if vim.g.dankcolors_active then
    if vim.fn.filereadable(dankcolors_path) == 1 then
      load_dankcolors()
    end
    return
  end

  local background = system_background()
  if background and vim.o.background ~= background then
    vim.o.background = background
  end

  if tostring(vim.g.colors_name or ""):match("^catppuccin") then
    pcall(vim.cmd.colorscheme, "catppuccin")
  end
end

if utils.is_asahi_linux() and vim.fn.filereadable(dankcolors_path) == 1 then
  vim.pack.add({
    gh("RRethy/base16-nvim"),
  })

  watch_dankcolors()
  if not load_dankcolors() then
    setup_catppuccin()
  end
else
  setup_catppuccin()
end

vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
  group = vim.api.nvim_create_augroup("adaptive_theme", { clear = true }),
  callback = refresh_theme,
})
