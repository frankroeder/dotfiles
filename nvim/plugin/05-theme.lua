local gh = require("pack_helpers").gh
local utils = require "utils"

local os_name = utils.os_name()
local dms_theme_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
local dms_term_path = vim.fn.expand("~/.cache/DankMaterialShell/zsh-colors.zsh")

local function hex_background(hex)
  local red = hex and tonumber(hex:sub(2, 3), 16)
  local green = hex and tonumber(hex:sub(4, 5), 16)
  local blue = hex and tonumber(hex:sub(6, 7), 16)
  if not red or not green or not blue then
    return nil
  end

  local luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255
  return luminance < 0.5 and "dark" or "light"
end

local function read_exports(path, prefix)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local values = {}
  local pattern = "^export%s+(" .. prefix .. "[%u_]+)%s*=%s*'([^']+)'"
  for _, line in ipairs(vim.fn.readfile(path)) do
    local key, value = line:match(pattern)
    if key and value then
      values[key] = value
    end
  end

  return next(values) and values or nil
end

local function dms_term_colors()
  return read_exports(dms_term_path, "DANK_TERM_")
end

local function dms_background()
  local term = dms_term_colors()
  if term then
    if term.DANK_TERM_MODE == "dark" or term.DANK_TERM_MODE == "light" then
      return term.DANK_TERM_MODE
    end
    return hex_background(term.DANK_TERM_BACKGROUND)
  end

  if vim.fn.filereadable(dms_theme_path) ~= 1 then
    return nil
  end

  for _, line in ipairs(vim.fn.readfile(dms_theme_path, "", 40)) do
    local base00 = line:match("base00%s*=%s*'(#%x%x%x%x%x%x)'")
    if base00 then
      return hex_background(base00)
    end
  end
end

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

local function current_background()
  if vim.g.dankcolors_active then
    return dms_background()
  end

  return system_background()
end

local function apply_base16_from_dms_term()
  local term = dms_term_colors()
  if not term or not term.DANK_TERM_BACKGROUND or not term.DANK_TERM_FOREGROUND then
    return
  end

  local ok, base16 = pcall(require, "base16-colorscheme")
  if not ok then
    return
  end

  base16.setup({
    base00 = term.DANK_TERM_BACKGROUND,
    base01 = term.DANK_TERM_BACKGROUND,
    base02 = term.DANK_TERM_SELECTION_BG or term.DANK_TERM_BRIGHT_BLACK,
    base03 = term.DANK_TERM_BRIGHT_BLACK,
    base04 = term.DANK_TERM_WHITE,
    base05 = term.DANK_TERM_FOREGROUND,
    base06 = term.DANK_TERM_FOREGROUND,
    base07 = term.DANK_TERM_BRIGHT_WHITE,
    base08 = term.DANK_TERM_RED,
    base09 = term.DANK_TERM_BRIGHT_RED,
    base0A = term.DANK_TERM_YELLOW,
    base0B = term.DANK_TERM_GREEN,
    base0C = term.DANK_TERM_CYAN,
    base0D = term.DANK_TERM_BLUE,
    base0E = term.DANK_TERM_MAGENTA,
    base0F = term.DANK_TERM_BRIGHT_MAGENTA,
  })

  vim.api.nvim_set_hl(0, "Normal", { bg = term.DANK_TERM_BACKGROUND, fg = term.DANK_TERM_FOREGROUND })
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = term.DANK_TERM_BACKGROUND, fg = term.DANK_TERM_FOREGROUND })
  if term.DANK_TERM_SELECTION_BG then
    vim.api.nvim_set_hl(0, "Visual", { bg = term.DANK_TERM_SELECTION_BG, fg = term.DANK_TERM_FOREGROUND })
  end
end

local function load_dms_theme()
  local ok, spec = pcall(dofile, dms_theme_path)
  local plugin = ok and spec and spec[1]
  if type(plugin) ~= "table" or type(plugin.config) ~= "function" then
    vim.notify("Failed to load DMS Neovim theme", vim.log.levels.WARN)
    return false
  end

  vim.g.dankcolors_active = true

  local background = dms_background()
  if background then
    vim.o.background = background
  end

  local configured, err = pcall(plugin.config)
  if not configured then
    vim.notify(("Failed to apply DMS Neovim theme: %s"):format(err), vim.log.levels.WARN)
    return false
  end

  apply_base16_from_dms_term()
  vim.api.nvim_exec_autocmds("User", { pattern = "DankcolorsReloaded", modeline = false })
  return true
end

local function watch_file_once(key, path, on_change)
  if _G[key] or vim.fn.filereadable(path) ~= 1 then
    return
  end

  local uv = vim.uv or vim.loop
  _G[key] = uv.new_fs_event()
  _G[key]:start(path, {}, vim.schedule_wrap(function()
    vim.defer_fn(on_change, 50)
  end))
end

local function watch_dms_theme()
  local reload = function()
    if load_dms_theme() then
      vim.notify("DMS theme reloaded", vim.log.levels.INFO)
    end
  end

  watch_file_once("_matugen_theme_watcher", dms_theme_path, reload)
  watch_file_once("_dank_term_colors_watcher", dms_term_path, reload)
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

local function refresh_background()
  local background = current_background()
  if not background or vim.o.background == background then
    return
  end

  vim.o.background = background
  if not vim.g.dankcolors_active and tostring(vim.g.colors_name or ""):match("^catppuccin") then
    pcall(vim.cmd.colorscheme, "catppuccin")
  end
end

if os_name == "Linux" and vim.fn.filereadable(dms_theme_path) == 1 then
  vim.pack.add({
    gh("RRethy/base16-nvim"),
  })

  watch_dms_theme()
  if not load_dms_theme() then
    setup_catppuccin()
  end
else
  setup_catppuccin()
end

local theme_switch_group = vim.api.nvim_create_augroup("adaptive_theme", { clear = true })

vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
  group = theme_switch_group,
  callback = refresh_background,
})
