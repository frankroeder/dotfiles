local mod = mainMod
local scripts = dotfilesDir .. "/asahi/bin"

local function quick(key)
  return "qs -c remix ipc call launcher quick " .. key
end

-- Apps and windows
hl.bind(mod .. " + T", hl.dsp.exec_cmd(launch(terminal)), { desc = "Terminal" })
hl.bind(mod .. " + Z", hl.dsp.exec_cmd(launch(filemanager)), { desc = "Filemanager" })
hl.bind(mod .. " + SPACE", hl.dsp.global "quickshell:launcher-toggle", { desc = "Launcher" })
hl.bind(
  mod .. " + SHIFT + W",
  hl.dsp.exec_cmd "qs -c remix ipc call wallpaper toggle",
  { desc = "Wallpaper picker" }
)
-- hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser), { desc = "Browser" })
hl.bind(mod .. " + Q", hl.dsp.window.close(), { desc = "Close window" })
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.kill(), { desc = "Kill process" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen { mode = 1 }, { desc = "Toggle maximized" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen(), { desc = "Toggle fullscreen" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { desc = "Toggle pseudo" })
hl.bind(mod .. " + R", hl.dsp.layout "togglesplit", { desc = "Toggle split" })
hl.bind(mod .. " + SHIFT + P", hl.dsp.window.pin(), { desc = "Toggle pin window (always on top)" })
hl.bind(mod .. " + W", hl.dsp.group.toggle(), { desc = "Toggle group" })
hl.bind(mod .. " + ALT + TAB", hl.dsp.group.next(), { desc = "Next window in group" })
hl.bind(mod .. " + ALT + SHIFT + TAB", hl.dsp.group.prev(), { desc = "Previous window in group" })
hl.bind(mod .. " + O", hl.dsp.exec_cmd(scripts .. "/asahi-window-pop"), { desc = "Pop window (float + center + pin)" })
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special "scratch", { desc = "Toggle scratchpad" })
hl.bind(
  mod .. " + SHIFT + S",
  hl.dsp.window.move { workspace = "special:scratch", silent = true },
  { desc = "Move to scratchpad" }
)
hl.bind(
  mod .. " + ALT + Return",
  hl.dsp.send_shortcut {
    mods = "SUPER + ALT",
    key = "Return",
    window = "class:^(com\\.mitchellh\\.ghostty)$",
  },
  { desc = "Quick terminal" }
)

-- Floating
hl.bind(mod .. " + SHIFT + T", hl.dsp.window.float(), { desc = "Toggle floating" })
hl.bind(mod .. " + C", hl.dsp.window.center(), { desc = "Center floating window" })

-- Resize: the Super+ALT variant of the Super+HJKL focus grammar. Tiled, this
-- pushes the shared border in that direction, so it grows the left/top window
-- and shrinks the right/bottom one — the direction is the constant, not "grow".
hl.bind(mod .. " + ALT + H", hl.dsp.window.resize { x = -100, y = 0, relative = true }, { desc = "Resize edge left" })
hl.bind(mod .. " + ALT + L", hl.dsp.window.resize { x = 100, y = 0, relative = true }, { desc = "Resize edge right" })
hl.bind(mod .. " + ALT + K", hl.dsp.window.resize { x = 0, y = -100, relative = true }, { desc = "Resize edge up" })
hl.bind(mod .. " + ALT + J", hl.dsp.window.resize { x = 0, y = 100, relative = true }, { desc = "Resize edge down" })

-- System panels and toggles: omarchy's Super+Ctrl+<letter> family.
hl.bind(mod .. " + CONTROL + A", hl.dsp.exec_cmd(quick "media"), { desc = "Audio" })
hl.bind(mod .. " + CONTROL + B", hl.dsp.exec_cmd(quick "bluetooth"), { desc = "Bluetooth" })
hl.bind(mod .. " + CONTROL + D", hl.dsp.exec_cmd(quick "monitors"), { desc = "Display" })
hl.bind(mod .. " + CONTROL + W", hl.dsp.exec_cmd(quick "network"), { desc = "Network" })
hl.bind(mod .. " + CONTROL + P", hl.dsp.exec_cmd(quick "battery"), { desc = "Power" })
hl.bind(mod .. " + CONTROL + S", hl.dsp.exec_cmd(quick "screenshots"), { desc = "Screenshot gallery" })
hl.bind(mod .. " + CONTROL + V", hl.dsp.exec_cmd(quick "clipboard"), { desc = "Clipboard history" })
hl.bind(mod .. " + CONTROL + T", hl.dsp.exec_cmd(scripts .. "/asahi-sysmon"), { desc = "Activity monitor" })
hl.bind(mod .. " + CONTROL + I", hl.dsp.exec_cmd(scripts .. "/asahi-stay-awake toggle"), { desc = "Stay awake" })
hl.bind(mod .. " + CONTROL + N", hl.dsp.exec_cmd(scripts .. "/asahi-nightlight"), { desc = "Night light" })
hl.bind(
  mod .. " + CONTROL + E",
  hl.dsp.exec_cmd "qs -c remix ipc call launcher openCategory Emoji",
  { desc = "Emoji picker" }
)
hl.bind(
  mod .. " + CONTROL + K",
  hl.dsp.exec_cmd "qs -c remix ipc call launcher openCategory Keys",
  { desc = "Keybindings" }
)
hl.bind(
  mod .. " + CONTROL + ALT + D",
  hl.dsp.exec_cmd "qs -c remix ipc call calendar toggle",
  { desc = "Calendar" }
)
hl.bind(mod .. " + CONTROL + plus", hl.dsp.exec_cmd(scripts .. "/asahi-monitor-scale up"), { desc = "Display scale up" })
hl.bind(mod .. " + CONTROL + minus", hl.dsp.exec_cmd(scripts .. "/asahi-monitor-scale down"), { desc = "Display scale down" })

-- Cursor magnifier, not the display scale above.
hl.bind(mod .. " + CONTROL + Z", function()
  hl.config { cursor = { zoom_factor = hl.get_config "cursor.zoom_factor" + 1 } }
end, { desc = "Zoom in" })
hl.bind(mod .. " + CONTROL + ALT + Z", function()
  hl.config { cursor = { zoom_factor = 1 } }
end, { desc = "Zoom reset" })

-- Session and screenshots
hl.bind(
  mod .. " + Escape",
  hl.dsp.exec_cmd("hyprlock --config " .. configDir .. "/hyprlock.conf"),
  { desc = "Lock" }
)
hl.bind(
  mod .. " + SHIFT + Escape",
  hl.dsp.exec_cmd "qs -c remix ipc call launcher openCategory System",
  { desc = "System menu" }
)
hl.bind(
  mod .. " + CONTROL + ALT + S",
  hl.dsp.exec_cmd "loginctl lock-session && systemctl suspend",
  { desc = "Suspend" }
) -- s2idle only (Asahi: no disk hibernation)

-- Mac capture row: Super+F10/F11/F12 (and bare media keys when fnmode=1).
hl.bind(mod .. " + F10", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot windows"), { desc = "Screenshot window" })
hl.bind(mod .. " + F11", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot smart"), { desc = "Screenshot smart" })
hl.bind(mod .. " + F12", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot fullscreen"), { desc = "Screenshot display" })
hl.bind(mod .. " + SHIFT + F11", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-ocr"), { desc = "OCR region" })
hl.bind(mod .. " + CONTROL + F11", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-qr"), { desc = "QR region" })
hl.bind(mod .. " + SHIFT + F12", hl.dsp.exec_cmd "hyprpicker -a", { desc = "Color picker" })
hl.bind(mod .. " + ALT + F11", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-record region"), { desc = "Record region (toggle)" })
hl.bind(mod .. " + ALT + F12", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-record fullscreen"), { desc = "Record focused display (toggle)" })
hl.bind(mod .. " + ALT + R", hl.dsp.global "quickshell:recorder-panel", { desc = "Recorder panel" })
hl.bind(mod .. " + ALT + SHIFT + F12", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-record webcam"), { desc = "Record display with webcam" })
hl.bind(mod .. " + ALT + code:34", hl.dsp.exec_cmd(scripts .. "/asahi-webcam resize smaller"), { desc = "Webcam overlay smaller" })
hl.bind(mod .. " + ALT + code:35", hl.dsp.exec_cmd(scripts .. "/asahi-webcam resize larger"), { desc = "Webcam overlay larger" })
hl.bind(mod .. " + XF86AudioMute", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot windows"), { locked = true, desc = "Screenshot window (top row)" })
hl.bind(mod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot smart"), { locked = true, desc = "Screenshot smart (top row)" })
hl.bind(mod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot fullscreen"), { locked = true, desc = "Screenshot display (top row)" })
hl.bind(mod .. " + SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd "hyprpicker -a", { locked = true, desc = "Color picker (top row)" })
hl.bind(mod .. " + ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-record region"), { locked = true, desc = "Record region (top row)" })
hl.bind(mod .. " + ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-record fullscreen"), { locked = true, desc = "Record display (top row)" })
hl.bind(mod .. " + ALT + SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-record webcam"), { locked = true, desc = "Record display with webcam (top row)" })
-- macOS muscle memory: Cmd+Shift+Ctrl+3/4/5 as aliases for the row above.
hl.bind(mod .. " + CONTROL + SHIFT + code:12", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot fullscreen"), { desc = "Screenshot display (Cmd+Shift+Ctrl+3)" })
hl.bind(mod .. " + CONTROL + SHIFT + code:13", hl.dsp.exec_cmd(scripts .. "/asahi-cmd-screenshot smart"), { desc = "Screenshot smart (Cmd+Shift+Ctrl+4)" })
hl.bind(mod .. " + CONTROL + SHIFT + code:14", hl.dsp.exec_cmd(quick "record"), { desc = "Capture menu (Cmd+Shift+Ctrl+5)" })

-- Notifications: the whole family lives on comma.
hl.bind(
  mod .. " + comma",
  hl.dsp.exec_cmd "qs -c remix ipc call notifications dismissOne",
  { desc = "Dismiss last notification" }
)
hl.bind(
  mod .. " + SHIFT + comma",
  hl.dsp.exec_cmd "qs -c remix ipc call notifications dismissAll",
  { desc = "Dismiss all notifications" }
)
hl.bind(
  mod .. " + CONTROL + comma",
  hl.dsp.exec_cmd "qs -c remix ipc call notifications toggleDnd",
  { desc = "Toggle notification DND" }
)
hl.bind(
  mod .. " + ALT + comma",
  hl.dsp.exec_cmd "qs -c remix ipc call notifications toggleHistory",
  { desc = "Notification history" }
)
-- Reloads
hl.bind(
  mod .. " + CONTROL + ALT + R",
  hl.dsp.exec_cmd(scripts .. "/asahi-reload-hyprland"),
  { desc = "Reload Hyprland" }
)
hl.bind(
  mod .. " + CONTROL + ALT + W",
  hl.dsp.exec_cmd(scripts .. "/asahi-restart-quickshell"),
  { desc = "Restart Quickshell" }
)
hl.bind(
  mod .. " + CONTROL + ALT + P",
  hl.dsp.exec_cmd(scripts .. "/asahi-restart-app hyprpaper"),
  { desc = "Restart hyprpaper" }
)
hl.bind(
  mod .. " + CONTROL + ALT + I",
  hl.dsp.exec_cmd(scripts .. "/asahi-restart-app hypridle"),
  { desc = "Restart hypridle" }
)

-- Focus
hl.bind(mod .. " + H", hl.dsp.focus { direction = "l" }, { desc = "Focus left" })
hl.bind(mod .. " + L", hl.dsp.focus { direction = "r" }, { desc = "Focus right" })
hl.bind(mod .. " + K", hl.dsp.focus { direction = "u" }, { desc = "Focus up" })
hl.bind(mod .. " + J", hl.dsp.focus { direction = "d" }, { desc = "Focus down" })

-- Move windows
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move { direction = "l" }, { desc = "Move left" })
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move { direction = "r" }, { desc = "Move right" })
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move { direction = "u" }, { desc = "Move up" })
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move { direction = "d" }, { desc = "Move down" })

-- Monitors. Unguarded, a direction with no display raises "monitor doesn't
-- exist" (an error toast for move, a log warning for focus) — laptop-only is
-- the normal case here, so both check first and no-op.
local dirs = { l = "left", r = "right", u = "up", d = "down" }
local keys = { l = "H", r = "L", u = "K", d = "J" }
local arrows = { l = "left", r = "right", u = "up", d = "down" }

for dir, name in pairs(dirs) do
  hl.bind(mod .. " + CONTROL + " .. arrows[dir], function()
    if hl.get_monitor(dir) then hl.dispatch(hl.dsp.focus { monitor = dir }) end
  end, { desc = "Focus monitor " .. name })
  hl.bind(mod .. " + SHIFT + CONTROL + " .. keys[dir], function()
    if hl.get_monitor(dir) then hl.dispatch(hl.dsp.window.move { monitor = dir }) end
  end, { desc = "Move to monitor " .. name })
end

-- Workspaces
for i = 1, 10 do
  local key = tostring(i % 10)
  hl.bind(mod .. " + " .. key, hl.dsp.focus { workspace = i }, { desc = "Workspace " .. i })
  hl.bind(
    mod .. " + CONTROL + " .. key,
    hl.dsp.window.move { workspace = i },
    { desc = "Move to workspace " .. i }
  )
end
hl.bind(mod .. " + TAB", hl.dsp.focus { workspace = "e+1" }, { desc = "Next workspace" })
hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus { workspace = "e-1" }, { desc = "Previous workspace" })

hl.bind(mod .. " + I", hl.dsp.focus { workspace = "e-1" }, { desc = "Previous workspace" })
hl.bind(mod .. " + U", hl.dsp.focus { workspace = "e+1" }, { desc = "Next workspace" })
hl.bind(mod .. " + Page_Up", hl.dsp.focus { workspace = "e-1" }, { desc = "Previous workspace" })
hl.bind(mod .. " + Page_Down", hl.dsp.focus { workspace = "e+1" }, { desc = "Next workspace" })
hl.bind(
  mod .. " + SHIFT + I",
  hl.dsp.window.move { workspace = "e-1" },
  { desc = "Move to previous workspace" }
)
hl.bind(
  mod .. " + SHIFT + U",
  hl.dsp.window.move { workspace = "e+1" },
  { desc = "Move to next workspace" }
)
hl.bind(
  mod .. " + SHIFT + Page_Up",
  hl.dsp.window.move { workspace = "e-1" },
  { desc = "Move to previous workspace" }
)
hl.bind(
  mod .. " + SHIFT + Page_Down",
  hl.dsp.window.move { workspace = "e+1" },
  { desc = "Move to next workspace" }
)

-- Mouse
hl.bind(mod .. " + mouse_down", hl.dsp.focus { workspace = "e+1" }, { desc = "Next workspace" })
hl.bind(mod .. " + mouse_up", hl.dsp.focus { workspace = "e-1" }, { desc = "Previous workspace" })
hl.bind(
  mod .. " + CONTROL + mouse_down",
  hl.dsp.window.move { workspace = "e+1" },
  { desc = "Move to next workspace" }
)
hl.bind(
  mod .. " + CONTROL + mouse_up",
  hl.dsp.window.move { workspace = "e-1" },
  { desc = "Move to previous workspace" }
)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, desc = "Drag window" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Resize window" })

-- Media
local function media_bind(key, action, opts)
  opts.locked = true
  hl.bind(key, hl.dsp.exec_cmd(scripts .. "/asahi-media-control " .. action), opts)
end

media_bind("XF86AudioRaiseVolume", "output-volume raise", { repeating = true, desc = "Volume up" })
media_bind(
  "XF86AudioLowerVolume",
  "output-volume lower",
  { repeating = true, desc = "Volume down" }
)
media_bind(
  "SHIFT + XF86AudioRaiseVolume",
  "output-volume +1",
  { repeating = true, desc = "Volume up 1%" }
)
media_bind(
  "SHIFT + XF86AudioLowerVolume",
  "output-volume -1",
  { repeating = true, desc = "Volume down 1%" }
)

media_bind("XF86AudioMute", "output-volume mute-toggle", { desc = "Mute" })
media_bind("SHIFT + XF86AudioMute", "output-switch", { desc = "Switch audio output" })
media_bind("XF86AudioMicMute", "input-volume mute-toggle", { desc = "Mic mute" })

media_bind("XF86AudioPlay", "playerctl play-pause", { desc = "Play pause" })
media_bind("XF86AudioPause", "playerctl play-pause", { desc = "Play pause" })
media_bind("XF86AudioNext", "playerctl next", { desc = "Next track" })
media_bind("XF86AudioPrev", "playerctl previous", { desc = "Previous track" })

hl.bind(
  "Caps_Lock",
  hl.dsp.exec_cmd("sleep 0.08; " .. scripts .. "/asahi-media-control caps-lock show"),
  { locked = true, desc = "Caps lock OSD" }
)

-- Display Brightness
media_bind("XF86MonBrightnessUp", "brightness raise", { repeating = true, desc = "Brightness up" })
media_bind(
  "XF86MonBrightnessDown",
  "brightness lower",
  { repeating = true, desc = "Brightness down" }
)
-- Fine display brightness on Shift, same as volume. Keyboard backlight is Search/LaunchA.
media_bind(
  "SHIFT + XF86MonBrightnessUp",
  "brightness +1",
  { repeating = true, desc = "Brightness fine up" }
)
media_bind(
  "SHIFT + XF86MonBrightnessDown",
  "brightness -1",
  { repeating = true, desc = "Brightness fine down" }
)

-- Keyboard Brightness
media_bind(
  "XF86Search",
  "keyboard-brightness raise",
  { repeating = true, desc = "Keyboard brightness up" }
)
media_bind(
  "XF86LaunchA",
  "keyboard-brightness lower",
  { repeating = true, desc = "Keyboard brightness down" }
)
media_bind(
  "SHIFT + XF86Search",
  "keyboard-brightness +1",
  { repeating = true, desc = "Keyboard brightness fine up" }
)
media_bind(
  "SHIFT + XF86LaunchA",
  "keyboard-brightness -1",
  { repeating = true, desc = "Keyboard brightness fine down" }
)
