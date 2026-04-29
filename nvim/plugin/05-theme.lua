local gh = require("pack_helpers").gh
local utils = require "utils"

local os_name = utils.os_name()
local dms_theme_path = vim.fn.expand("~/.config/DankMaterialShell/matugen.vim")

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

local function matugen_background()
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

local function load_matugen()
  local ok, spec = pcall(dofile, dms_theme_path)
  local plugin = ok and type(spec) == "table" and spec[1]
  if type(plugin) ~= "table" or type(plugin.config) ~= "function" then
    vim.notify("Failed to load DMS Neovim theme", vim.log.levels.WARN)
    return false
  end

  local background = matugen_background()
  if background then
    vim.o.background = background
  end

  -- The generated file still contains its old self-watcher. Reload is handled here.
  _G._matugen_theme_watcher = _G._matugen_theme_watcher or true

  local configured, err = pcall(plugin.config)
  if not configured then
    vim.notify(("Failed to apply DMS Neovim theme: %s"):format(err), vim.log.levels.WARN)
    return false
  end

  vim.g.dankcolors_active = true
  vim.api.nvim_exec_autocmds("User", { pattern = "DankcolorsReloaded", modeline = false })
  return true
end

local function watch_matugen()
  if _G._dms_matugen_signal then
    return
  end

  local uv = vim.uv or vim.loop
  _G._dms_matugen_signal = uv.new_signal()
  _G._dms_matugen_signal:start("sigusr1", vim.schedule_wrap(function()
    if load_matugen() then
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

local function refresh_catppuccin_background()
  if vim.g.dankcolors_active or not tostring(vim.g.colors_name or ""):match("^catppuccin") then
    return
  end

  local background = system_background()
  if background and vim.o.background ~= background then
    vim.o.background = background
    pcall(vim.cmd.colorscheme, "catppuccin")
  end
end

if utils.is_asahi_linux() and vim.fn.filereadable(dms_theme_path) == 1 then
  vim.pack.add({
    gh("RRethy/base16-nvim"),
  })

  watch_matugen()
  if not load_matugen() then
    setup_catppuccin()
  end
else
  setup_catppuccin()
end

vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
  group = vim.api.nvim_create_augroup("adaptive_theme", { clear = true }),
  callback = refresh_catppuccin_background,
})
