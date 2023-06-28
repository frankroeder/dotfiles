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
config.scrollback_lines = 10000
config.keys = {
	{
		key = "t",
		mods = "ALT",
		action = wezterm.action.ShowTabNavigator,
	},
	{
		key = "/",
		mods = "SHIFT|CTRL",
		action = wezterm.action({ SendString = "\\" }),
	},
	{
		key = "+",
		mods = "CMD",
		action = "IncreaseFontSize",
	},
	{ key = "-", mods = "CMD", action = "DecreaseFontSize" },
	{
		key = "f",
		mods = "CMD",
		action = wezterm.action.Search({ CaseSensitiveString = "" }),
	},
	{
		key = "V",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ActivateCopyMode,
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

wezterm.on("update-right-status", function(window, pane)
	local success, stdout, stderr = wezterm.run_child_process({ "bash", "wezterm_status" })
	if not success then
		wezterm.log_error("Could not create child", stdout, stderr)
	end
	window:set_right_status(wezterm.format({
		{ Background = { Color = "#313244" } },
		{ Foreground = { Color = "#74c7ec" } },
		{ Text = stdout },
	}))
end)

return config
