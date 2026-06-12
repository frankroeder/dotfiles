-- Catppuccin Mocha (dark) + Latte (light) for sketchybar, auto based on system appearance.
-- Matches nvim (catppuccin), ghostty, terminal-theme.sh etc.
-- Edit the palettes or ws/indicator keys here for global scheme changes.
-- On theme toggle via bottom bar mode item, bars reload to pick fresh colors.

local function detect_dark()
  local env = os.getenv("CATPPUCCIN_TERM_MODE") or ""
  if env == "dark" then return true end
  if env == "light" then return false end

  -- Prefer osascript (matches the toggle command; more reliable immediately after set)
  local h = io.popen([[osascript -e 'tell application "System Events" to tell appearance preferences to return dark mode' 2>/dev/null || echo "false"]])
  if h then
    local out = (h:read("*a") or ""):lower():gsub("%s+", "")
    h:close()
    if out == "true" then return true end
    if out == "false" then return false end
  end

  -- macOS fallback
  h = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light")
  if h then
    local out = (h:read("*a") or ""):lower()
    h:close()
    if out:match("dark") then return true end
  end

  -- linux fallback
  h = io.popen("gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo ''")
  if h then
    local out = (h:read("*a") or ""):lower()
    h:close()
    if out:match("dark") or out:match("prefer%-dark") then return true end
  end
  return true
end

local is_dark = detect_dark()

local mocha = {
  base = 0xff1e1e2e,
  mantle = 0xff181825,
  crust = 0xff11111b,
  surface0 = 0xff313244,
  surface1 = 0xff45475a,
  surface2 = 0xff585b70,
  overlay0 = 0xff6c7086,
  overlay1 = 0xff7f849c,
  overlay2 = 0xff9399b2,
  subtext0 = 0xffa6adc8,
  subtext1 = 0xffbac2de,
  text = 0xffcdd6f4,
  lavender = 0xffb4befe,
  blue = 0xff89b4fa,
  sapphire = 0xff74c7ec,
  sky = 0xff89dceb,
  teal = 0xff94e2d5,
  green = 0xffa6e3a1,
  yellow = 0xfff9e2af,
  peach = 0xfffab387,
  maroon = 0xffeba0ac,
  red = 0xfff38ba8,
  mauve = 0xffcba6f7,
  pink = 0xfff5c2e7,
  flamingo = 0xfff2cdcd,
  rosewater = 0xfff5e0dc,
  black = 0xff45475a,
  white = 0xffcdd6f4,
  grey = 0xff6c7086,
  orange = 0xfffab387,
  magenta = 0xfff5c2e7,
  purple = 0xffcba6f7,
  dirty_white = 0xffbac2de,
  lightblack = 0xff585b70,
}

local latte = {
  base = 0xffeff1f5,
  mantle = 0xffe6e9ef,
  crust = 0xffdce0e8,
  surface0 = 0xffccd0da,
  surface1 = 0xffbcc0cc,
  surface2 = 0xffacb0be,
  overlay0 = 0xff9ca0b0,
  overlay1 = 0xff8c8fa1,
  overlay2 = 0xff7c7f93,
  subtext0 = 0xff6c6f85,
  subtext1 = 0xff5c5f77,
  text = 0xff4c4f69,
  lavender = 0xff7287fd,
  blue = 0xff1e66f5,
  sapphire = 0xff209fb5,
  sky = 0xff04a5e5,
  teal = 0xff179299,
  green = 0xff40a02b,
  yellow = 0xffdf8e1d,
  peach = 0xfffe640b,
  maroon = 0xffe64553,
  red = 0xffd20f39,
  mauve = 0xff8839ef,
  pink = 0xffea76cb,
  flamingo = 0xffdd7878,
  rosewater = 0xffdc8a78,
  black = 0xff5c5f77,
  white = 0xff4c4f69,
  grey = 0xff9ca0b0,
  orange = 0xfffe640b,
  magenta = 0xffea76cb,
  purple = 0xff8839ef,
  dirty_white = 0xff5c5f77,
  lightblack = 0xff7c7f93,
}

local p = is_dark and mocha or latte

local c = {}
for k, v in pairs(p) do
  c[k] = v
end
c.transparent = 0x00000000
c.is_dark = is_dark

c.with_alpha = function(color, alpha)
  if alpha > 1.0 or alpha < 0.0 then
    return color
  end
  return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
end

-- bar / popup / misc (trans bar good for both, popup adapts)
c.bar = { bg = c.transparent, border = c.transparent }
c.popup = {
  bg = c.with_alpha(is_dark and c.mantle or c.base, 0.92),
  border = c.blue,
}
c.bg = c.base
c.bg1 = is_dark and c.crust or c.mantle
c.bg2 = is_dark and c.crust or c.mantle
c.bg3 = c.surface0
c.pill_bg = c.surface0
c.bar_color = c.transparent
c.bar_border_color = c.transparent

-- global easy retune keys (use these or ws.* for scheme)
c.vol = c.sky
c.bat = c.peach
c.mic = c.teal
c.cal = c.subtext0

-- workspace overview colors (lavender pop like ref rose; sel inverts fg for contrast)
c.ws = {
  bg = c.with_alpha(c.crust, is_dark and 0.58 or 0.72),
  border = c.with_alpha(c.blue, 0.28),
  fg = c.lavender,
  sel_bg = c.lavender,
  sel_fg = is_dark and c.crust or c.base,
}

return c
