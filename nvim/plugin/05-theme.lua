local gh = require("pack_helpers").gh
local utils = require "utils"

local os_name = utils.os_name()
local dankcolors_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
local use_dankcolors = os_name == "Linux" and vim.fn.filereadable(dankcolors_path) == 1

local function background_from_dankcolors()
  if vim.fn.filereadable(dankcolors_path) ~= 1 then
    return nil
  end

  for _, line in ipairs(vim.fn.readfile(dankcolors_path, "", 40)) do
    local hex = line:match("base00%s*=%s*'(#%x%x%x%x%x%x)'")
    if hex then
      local red = tonumber(hex:sub(2, 3), 16)
      local green = tonumber(hex:sub(4, 5), 16)
      local blue = tonumber(hex:sub(6, 7), 16)
      local luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255
      return luminance < 0.5 and "dark" or "light"
    end
  end

  return nil
end

local function load_dankcolors()
  local ok, spec = pcall(dofile, dankcolors_path)
  local plugin = ok and spec and spec[1]
  if type(plugin) ~= "table" or type(plugin.config) ~= "function" then
    vim.notify("Failed to load DMS Neovim theme", vim.log.levels.WARN)
    return false
  end

  vim.g.dankcolors_active = true

  local background = background_from_dankcolors()
  if background then
    vim.o.background = background
  end

  local configured, err = pcall(plugin.config)
  if not configured then
    vim.notify(("Failed to apply DMS Neovim theme: %s"):format(err), vim.log.levels.WARN)
    return false
  end

  vim.api.nvim_exec_autocmds("User", { pattern = "DankcolorsReloaded", modeline = false })
  return true
end

local function watch_dankcolors()
  if _G._matugen_theme_watcher then
    return
  end

  local uv = vim.uv or vim.loop
  _G._matugen_theme_watcher = uv.new_fs_event()
  _G._matugen_theme_watcher:start(dankcolors_path, {}, vim.schedule_wrap(function()
    vim.defer_fn(function()
      if load_dankcolors() then
        vim.notify("DMS theme reloaded", vim.log.levels.INFO)
      end
    end, 50)
  end))
end

local function setup_catppuccin()
  vim.g.dankcolors_active = false

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
end

if use_dankcolors then
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

local function detect_background()
  if vim.g.dankcolors_active then
    return background_from_dankcolors()
  end

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
