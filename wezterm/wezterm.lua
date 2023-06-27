local wezterm = require("wezterm")
local wezdir = os.getenv("HOME") .. "/.config/wezterm"
local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.window_background_opacity = 0.85

-- config.enable_tab_bar = false
config.front_end = "WebGpu"
config.window_decorations = "RESIZE"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 16
config.adjust_window_size_when_changing_font_size = false
config.native_macos_fullscreen_mode = true
config.window_close_confirmation = "NeverPrompt"
config.automatically_reload_config = true
config.audible_bell = "Disabled"
config.keys = {
	{
		key = "n",
		mods = "SHIFT|CTRL",
		action = wezterm.action.ToggleFullScreen,
	},
	{
		key = "t",
		mods = "ALT",
		action = wezterm.action.ShowTabNavigator,
	},
}

config.color_scheme = "Catppuccin Mocha"
config.default_cursor_style = "BlinkingUnderline"
config.background = {
	{
		source = {
			Gradient = {
				orientation = "Horizontal",
				colors = {
					"#00000C",
					"#000026",
					"#00000C",
				},
				interpolation = "CatmullRom",
				blend = "Rgb",
				noise = 0,
			},
		},
		width = "100%",
		height = "100%",
		opacity = 0.85,
	},
	{
		source = {
			File = { path = wezdir .. "/4.gif", speed = 0.4 },
		},
		repeat_y = "Mirror",
		width = "100%",
		opacity = 0.10,
		hsb = {
			hue = 0.6,
			saturation = 0.9,
			brightness = 0.1,
		},
	},
	{
		source = {
			File = { path = wezdir .. "/pulsing.gif", speed = 0.4 },
		},
		repeat_y = "Mirror",
		width = "100%",
		opacity = 0.05,
		hsb = {
			hue = 0.6,
			saturation = 0.9,
			brightness = 0.1,
		},
	},
}

return config
