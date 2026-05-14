local mod = mainMod
local scripts = dotfilesDir .. "/asahi/bin"

-- Apps and windows
hl.bind(mod .. " + T", hl.dsp.exec_cmd(terminal), { desc = "Terminal" })
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(launcher), { desc = "Launcher" })
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser), { desc = "Browser" })
hl.bind(mod .. " + Q", hl.dsp.exec_cmd(scripts .. "/hypr-killactive"), { desc = "Kill active process" })
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close(), { desc = "Close window" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }), { desc = "Toggle maximized" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen(), { desc = "Toggle fullscreen" })
hl.bind(mod .. " + SHIFT + T", hl.dsp.window.float(), { desc = "Toggle floating" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { desc = "Toggle pseudo" })
hl.bind(mod .. " + R", hl.dsp.layout("togglesplit"), { desc = "Toggle split" })
hl.bind(mod .. " + W", hl.dsp.group.toggle(), { desc = "Toggle group" })
hl.bind(mod .. " + M", hl.dsp.exec_cmd(scripts .. "/asahi-feature-menu"), { desc = "Feature menu" })
hl.bind(mod .. " + N", hl.dsp.exec_cmd(scripts .. "/asahi-network-menu"), { desc = "Network menu" })
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("scratch"), { desc = "Toggle scratchpad" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch", silent = true }), { desc = "Move to scratchpad" })
hl.bind(mod .. " + ALT + Return", hl.dsp.exec_cmd(scripts .. "/asahi-special-terminal"), { desc = "Special terminal" })

-- Session and screenshots
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("hyprlock --config " .. configDir .. "/hyprlock.conf"), { desc = "Lock" })
hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd(scripts .. "/asahi-control-menu"), { desc = "Control menu" })
hl.bind(mod .. " + CONTROL + ALT + S", hl.dsp.exec_cmd("loginctl lock-session && systemctl suspend"), { desc = "Suspend" })
hl.bind(mod .. " + ALT + CONTROL + 2", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot smart"), { desc = "Screenshot smart" })
hl.bind(mod .. " + ALT + CONTROL + 3", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot fullscreen"), { desc = "Screenshot fullscreen" })
hl.bind(mod .. " + ALT + CONTROL + 4", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot region"), { desc = "Screenshot region" })

-- Reloads
hl.bind(mod .. " + CONTROL + ALT + R", hl.dsp.exec_cmd(scripts .. "/asahi-reload-hyprland"), { desc = "Reload Hyprland" })
hl.bind(mod .. " + CONTROL + ALT + SPACE", hl.dsp.exec_cmd(scripts .. "/asahi-restart-walker"), { desc = "Restart walker" })
hl.bind(
  mod .. " + CONTROL + ALT + W",
  hl.dsp.exec_cmd(scripts .. "/asahi-restart-app waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css"),
  { desc = "Restart waybar" }
)
hl.bind(
  mod .. " + CONTROL + ALT + M",
  hl.dsp.exec_cmd(scripts .. "/asahi-restart-app mako --config ~/.config/mako/config"),
  { desc = "Restart mako" }
)
hl.bind(mod .. " + CONTROL + ALT + P", hl.dsp.exec_cmd(scripts .. "/asahi-restart-app hyprpaper"), { desc = "Restart hyprpaper" })
hl.bind(mod .. " + CONTROL + ALT + I", hl.dsp.exec_cmd(scripts .. "/asahi-restart-app hypridle"), { desc = "Restart hypridle" })

-- Focus
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }), { desc = "Focus left" })
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }), { desc = "Focus right" })
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }), { desc = "Focus up" })
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }), { desc = "Focus down" })
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }), { desc = "Focus left" })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }), { desc = "Focus right" })
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "u" }), { desc = "Focus up" })
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "d" }), { desc = "Focus down" })
hl.bind(mod .. " + Home", hl.dsp.focus({ window = "first" }), { desc = "Focus first" })
hl.bind(mod .. " + End", hl.dsp.focus({ window = "last" }), { desc = "Focus last" })

-- Move windows
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }), { desc = "Move left" })
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }), { desc = "Move right" })
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }), { desc = "Move up" })
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }), { desc = "Move down" })
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }), { desc = "Move left" })
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }), { desc = "Move right" })
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "u" }), { desc = "Move up" })
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "d" }), { desc = "Move down" })

-- Monitors
hl.bind(mod .. " + CONTROL + left", hl.dsp.focus({ monitor = "l" }), { desc = "Focus monitor left" })
hl.bind(mod .. " + CONTROL + right", hl.dsp.focus({ monitor = "r" }), { desc = "Focus monitor right" })
hl.bind(mod .. " + CONTROL + up", hl.dsp.focus({ monitor = "u" }), { desc = "Focus monitor up" })
hl.bind(mod .. " + CONTROL + down", hl.dsp.focus({ monitor = "d" }), { desc = "Focus monitor down" })
hl.bind(mod .. " + SHIFT + CONTROL + H", hl.dsp.window.move({ monitor = "l" }), { desc = "Move to monitor left" })
hl.bind(mod .. " + SHIFT + CONTROL + L", hl.dsp.window.move({ monitor = "r" }), { desc = "Move to monitor right" })
hl.bind(mod .. " + SHIFT + CONTROL + K", hl.dsp.window.move({ monitor = "u" }), { desc = "Move to monitor up" })
hl.bind(mod .. " + SHIFT + CONTROL + J", hl.dsp.window.move({ monitor = "d" }), { desc = "Move to monitor down" })

-- Workspaces
for i = 1, 10 do
  local key = tostring(i % 10)
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }), { desc = "Workspace " .. i })
  hl.bind(mod .. " + CONTROL + " .. key, hl.dsp.window.move({ workspace = i }), { desc = "Move to workspace " .. i })
end

hl.bind(mod .. " + I", hl.dsp.focus({ workspace = "e-1" }), { desc = "Previous workspace" })
hl.bind(mod .. " + U", hl.dsp.focus({ workspace = "e+1" }), { desc = "Next workspace" })
hl.bind(mod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }), { desc = "Previous workspace" })
hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }), { desc = "Next workspace" })
hl.bind(mod .. " + SHIFT + I", hl.dsp.window.move({ workspace = "e-1" }), { desc = "Move to previous workspace" })
hl.bind(mod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "e+1" }), { desc = "Move to next workspace" })
hl.bind(mod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1" }), { desc = "Move to previous workspace" })
hl.bind(mod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1" }), { desc = "Move to next workspace" })

-- Mouse
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { desc = "Next workspace" })
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { desc = "Previous workspace" })
hl.bind(mod .. " + CONTROL + mouse_down", hl.dsp.window.move({ workspace = "e+1" }), { desc = "Move to next workspace" })
hl.bind(mod .. " + CONTROL + mouse_up", hl.dsp.window.move({ workspace = "e-1" }), { desc = "Move to previous workspace" })
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, desc = "Drag window" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Resize window" })

-- Media
local function media_bind(key, action, opts)
  opts.locked = true
  hl.bind(key, hl.dsp.exec_cmd(scripts .. "/asahi-media-control " .. action), opts)
end

media_bind("XF86AudioRaiseVolume", "output-volume raise", { repeating = true, desc = "Volume up" })
media_bind("XF86AudioLowerVolume", "output-volume lower", { repeating = true, desc = "Volume down" })
media_bind("XF86AudioMute", "output-volume mute-toggle", { desc = "Mute" })
media_bind("XF86AudioMicMute", "input-volume mute-toggle", { desc = "Mic mute" })
media_bind("XF86AudioPlay", "playerctl play-pause", { desc = "Play pause" })
media_bind("XF86AudioPause", "playerctl play-pause", { desc = "Play pause" })
media_bind("XF86AudioNext", "playerctl next", { desc = "Next track" })
media_bind("XF86AudioPrev", "playerctl previous", { desc = "Previous track" })
hl.bind("Caps_Lock", hl.dsp.exec_cmd("sleep 0.08; " .. scripts .. "/asahi-swayosd --caps-lock"), { locked = true, desc = "Caps lock OSD" })

-- Brightness
media_bind("XF86MonBrightnessUp", "brightness raise", { repeating = true, desc = "Brightness up" })
media_bind("XF86MonBrightnessDown", "brightness lower", { repeating = true, desc = "Brightness down" })
media_bind("SHIFT + XF86MonBrightnessUp", "brightness +1", { repeating = true, desc = "Brightness fine up" })
media_bind("SHIFT + XF86MonBrightnessDown", "brightness -1", { repeating = true, desc = "Brightness fine down" })
media_bind("XF86KbdBrightnessUp", "keyboard-brightness raise", { repeating = true, desc = "Keyboard brightness up" })
media_bind("XF86KbdBrightnessDown", "keyboard-brightness lower", { repeating = true, desc = "Keyboard brightness down" })
media_bind("F4", "keyboard-brightness raise", { repeating = true, desc = "Keyboard brightness up" })
media_bind("F3", "keyboard-brightness lower", { repeating = true, desc = "Keyboard brightness down" })
media_bind("SHIFT + F4", "keyboard-brightness +1", { repeating = true, desc = "Keyboard brightness fine up" })
media_bind("SHIFT + F3", "keyboard-brightness -1", { repeating = true, desc = "Keyboard brightness fine down" })
