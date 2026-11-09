local gh = require("pack_helpers").gh

local function system_background()
  local sysname = (vim.uv or vim.loop).os_uname().sysname

  if sysname == "Darwin" and vim.fn.executable "defaults" == 1 then
    local result = vim.fn.system { "defaults", "read", "-g", "AppleInterfaceStyle" }
    return vim.v.shell_error == 0 and result:match "Dark" and "dark" or "light"
  end

  if sysname == "Linux" and vim.fn.executable "gsettings" == 1 then
    local color_scheme =
      vim.fn.system { "gsettings", "get", "org.gnome.desktop.interface", "color-scheme" }
    if vim.v.shell_error == 0 and color_scheme:match "prefer%-dark" then
      return "dark"
    end
    if vim.v.shell_error == 0 and color_scheme:match "prefer%-light" then
      return "light"
    end

    local gtk_theme =
      vim.fn.system { "gsettings", "get", "org.gnome.desktop.interface", "gtk-theme" }
    if vim.v.shell_error == 0 and gtk_theme:lower():match "dark" then
      return "dark"
    end

    return "light"
  end

  return vim.o.background == "light" and "light" or "dark"
end

vim.pack.add {
  { src = gh "catppuccin/nvim", name = "catppuccin" },
}

-- Wallpaper hues from asahi-autotheme (nil off-Asahi: files absent).
local function theme_file(name)
  local state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
  local f = io.open(state .. "/asahi-theme/" .. name, "r")
  if not f then return nil end
  local raw = f:read "*a"
  f:close()
  return raw
end

local function setup_catppuccin(background)
  local overrides = {}
  local raw = theme_file "colors.json"
  if raw then
    local ok, colors = pcall(vim.json.decode, raw)
    if ok and type(colors) == "table" and colors.mode == background then
      local flavor = background == "light" and "latte" or "mocha"
      local over = {}
      for _, k in ipairs { "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green",
        "teal", "sky", "sapphire", "blue", "lavender", "text", "subtext1", "subtext0", "overlay2", "overlay1",
        "overlay0", "surface2", "surface1", "surface0", "base", "mantle", "crust" } do
        if type(colors[k]) == "string" then over[k] = colors[k] end
      end
      overrides = { [flavor] = over }
    end
  end
  require("catppuccin").setup {
    background = { light = "latte", dark = "mocha" },
    transparent_background = true,
    color_overrides = overrides,
    integrations = {
      blink_cmp = true,
      gitsigns = true,
      markdown = true,
      native_lsp = { enabled = true, inlay_hints = { background = true } },
      render_markdown = true,
      treesitter = true,
    },
  }
end

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

-- Setup once, then only when the wallpaper changes (theme.name bump); FocusGained just re-checks light/dark.
local last_marker = false
local function refresh_theme()
  local background = system_background()
  local marker = theme_file "theme.name"
  if marker ~= last_marker then
    last_marker = marker
    setup_catppuccin(background)
  end
  set_theme(background)
end

refresh_theme()

vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
  group = vim.api.nvim_create_augroup("adaptive_theme", { clear = true }),
  callback = refresh_theme,
})
