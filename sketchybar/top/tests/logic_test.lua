-- Drive the shipped top-bar helpers. No sbar, no reimplementation of tables.
local src = debug.getinfo(1, "S").source:gsub("^@", "")
if not src:match "^/" then
  local pwd = os.getenv "PWD" or "."
  src = pwd .. "/" .. src
end
local root = src:gsub("sketchybar/top/tests/logic_test.lua$", "")
if root == src then
  root = os.getenv "DOTFILES" or (os.getenv "HOME" .. "/.dotfiles")
  if root:sub(-1) ~= "/" then
    root = root .. "/"
  end
end

package.path = root
  .. "sketchybar/?.lua;"
  .. root
  .. "sketchybar/?/init.lua;"
  .. root
  .. "sketchybar/top/?.lua;"
  .. package.path

local logic = require "logic"
local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local groups = require "groups"

local failures = 0
local function fail(msg)
  failures = failures + 1
  io.stderr:write("FAIL " .. msg .. "\n")
end

local function ok(cond, msg)
  if cond then
    print("ok  " .. msg)
  else
    fail(msg)
  end
end

local function eq(got, expected, msg)
  if got == expected then
    print("ok  " .. msg)
  else
    fail(msg .. " got=" .. tostring(got) .. " expected=" .. tostring(expected))
  end
end

-- space pills
local empty_unfocused = logic.space_pill("", false, "1")
ok(empty_unfocused.drawing == false, "empty-unfocused not drawn")
eq(empty_unfocused.icon_string, "", "empty-unfocused no number")
eq(empty_unfocused.label_string, "", "empty-unfocused no icons")

local focused_empty = logic.space_pill("", true, "4")
ok(focused_empty.drawing == true, "focused-empty drawn")
ok(focused_empty.show_number == true, "focused-empty shows number")
eq(focused_empty.icon_string, "4", "focused-empty icon is workspace id")
eq(focused_empty.label_string, "", "focused-empty no app icons")
ok(focused_empty.label_drawing == false, "focused-empty label off")
eq(focused_empty.pad, logic.pill_padding.active_empty, "focused-empty pad")
eq(focused_empty.icon_padding_left, logic.pill_padding.active_empty, "focused-empty pad L")
eq(focused_empty.icon_padding_right, logic.pill_padding.active_empty, "focused-empty pad R")

local focused_occ = logic.space_pill(":ghostty:", true, "2")
ok(focused_occ.drawing == true, "focused-occupied drawn")
eq(focused_occ.icon_string, "2", "focused-occupied shows number")
eq(focused_occ.label_string, ":ghostty:", "focused-occupied shows icons")
ok(focused_occ.label_drawing == true, "focused-occupied label on")
eq(focused_occ.pad, logic.pill_padding.active_icons, "focused-occupied pad")
eq(focused_occ.icon_padding_right, logic.number_icon_gap, "focused-occupied number-icon gap")

local occ_unfocused = logic.space_pill(":safari: :mail:", false, "3")
ok(occ_unfocused.drawing == true, "occupied-unfocused drawn")
eq(occ_unfocused.icon_string, "", "occupied-unfocused hides number")
eq(occ_unfocused.label_string, ":safari: :mail:", "occupied-unfocused keeps app icons")
ok(occ_unfocused.label_drawing == true, "occupied-unfocused label on")
eq(occ_unfocused.pad, logic.pill_padding.inactive, "occupied-unfocused pad")
eq(occ_unfocused.label_y, -1, "multi-icon y_offset")

local theme = {
  focused_bg = 0x1,
  unfocused_bg = 0x2,
  focused_text = 0x3,
  unfocused_text = 0x4,
}
local props = logic.space_set_props(focused_occ, theme)
eq(props.background.color, theme.focused_bg, "focused pill uses focused_bg")
eq(props.icon.string, "2", "set_props icon")
eq(props.label.string, ":ghostty:", "set_props label")

-- volume thresholds 0 / 10 / 33 / 66 / 100 (flameberry >60/>30/>10/>0)
eq(logic.volume_band(0), 0, "volume 0 → 0")
eq(logic.volume_icon(0), icons.volume[0], "volume 0 icon")
eq(logic.volume_band(10), 10, "volume 10 → 10")
eq(logic.volume_icon(10), icons.volume[10], "volume 10 icon")
eq(logic.volume_band(33), 66, "volume 33 → 66")
eq(logic.volume_icon(33), icons.volume[66], "volume 33 icon")
eq(logic.volume_band(66), 100, "volume 66 → 100")
eq(logic.volume_icon(66), icons.volume[100], "volume 66 icon")
eq(logic.volume_band(100), 100, "volume 100 → 100")
eq(logic.volume_icon(100), icons.volume[100], "volume 100 icon")
eq(logic.volume_band(50, true), 0, "muted → 0")
eq(logic.volume_label(5), "05%", "volume leading zero")
eq(logic.volume_label(100), "100%", "volume 100 label")

-- battery bands + charging (shipped icons/colors, not a copied table)
local charging = logic.battery_visual(80, true)
eq(charging.band, "charging", "battery charging band")
eq(charging.icon, icons.battery.charging, "battery charging icon")
eq(charging.color, colors.green, "battery charging color")

local b100 = logic.battery_visual(80, false)
eq(b100.band, "100", "battery >60 → 100")
eq(b100.icon, icons.battery["100"], "battery 100 icon")
eq(b100.color, colors.blue, "battery 100 color")

local b75 = logic.battery_visual(50, false)
eq(b75.band, "75", "battery >40 → 75")
eq(b75.icon, icons.battery["75"], "battery 75 icon")
eq(b75.color, colors.yellow, "battery 75 color")

local b50 = logic.battery_visual(30, false)
eq(b50.band, "50", "battery >20 → 50")
eq(b50.icon, icons.battery["50"], "battery 50 icon")

local b25 = logic.battery_visual(15, false)
eq(b25.band, "25", "battery >10 → 25")
eq(b25.icon, icons.battery["25"], "battery 25 icon")

local b0 = logic.battery_visual(5, false)
eq(b0.band, "0", "battery low → 0")
eq(b0.icon, icons.battery["0"], "battery 0 icon")
eq(b0.color, colors.red, "battery low color")
eq(logic.battery_label(5), "05%", "battery leading zero")

-- media width / truncate
eq(logic.display_width "abc", 3, "ascii width")
eq(logic.display_width "日本語", 6, "CJK width is double")
eq(logic.display_width "", 0, "empty width")
eq(logic.truncate("abcdefghij", 5), "abcd…", "ascii truncate")
eq(logic.truncate("日本語です", 5), "日本…", "CJK truncate")
eq(logic.truncate("short", 20), "short", "no truncate when short")
eq(logic.media_display("Title", "Artist", 20), "Title – Artist", "media title – artist")
eq(logic.media_display("Title", ""), "Title", "media title only")
eq(logic.IDLE_COPY, "It's pretty silent in here...", "idle copy")
ok(logic.media_display("Title", "Artist") ~= logic.IDLE_COPY, "track label is not idle copy")
local cjk_media = logic.media_display("日本語の曲", "歌手", 8)
ok(logic.display_width(cjk_media) <= 8, "media CJK stays within budget")
ok(cjk_media:find "…", "media CJK truncated")

-- weather
eq(logic.weather_label "+33°C", "+33°C", "weather accepts +33°C")
eq(logic.weather_label "  +33°C\n", "+33°C", "weather trims")
ok(logic.weather_label "" == nil, "weather rejects empty")
ok(logic.weather_label(nil) == nil, "weather rejects nil")
ok(logic.weather_label "unknown" == nil, "weather rejects unknown")
ok(logic.weather_label "Unknown location" == nil, "weather rejects Unknown")

-- wifi: ifconfig status token; "inactive" must not count as connected
ok(logic.wifi_connected "active" == true, "wifi active → connected")
ok(logic.wifi_connected "inactive" == false, "wifi inactive → disconnected")
ok(logic.wifi_connected "  inactive\n" == false, "wifi inactive trims")
ok(logic.wifi_connected "  active\n" == true, "wifi active trims")
ok(logic.wifi_connected "" == false, "wifi empty → disconnected")

-- composition (shipped groups.lua) — original widgets on the solid bar
ok(groups.left[1]:find "space", "left has space glob")
eq(groups.left[2], "widgets.yabai_layout", "left has layout pill")
ok(groups.center == nil, "no center group")
local right = {}
for _, name in ipairs(groups.right) do
  right[name] = true
end
ok(right["widgets.calendar"], "right calendar")
ok(right["widgets.battery"], "right battery")
ok(right["widgets.brew"], "right brew")
ok(right["widgets.coffee"], "right coffee")
ok(right["widgets.bluetooth"], "right bluetooth")
ok(right["widgets.wifi"], "right wifi")
ok(right["widgets.network_up"], "right network-up")
ok(right["widgets.volume"], "right volume")
ok(right["widgets.mic"], "right mic")
ok(right["widgets.ccu"], "right ccu")
ok(not right["center.weather"], "weather not on the bar")
ok(not right["center.media"], "media not on the bar")

local function read_src(rel)
  local fh = io.open(root .. rel, "r")
  if not fh then
    fail("missing " .. rel)
    return ""
  end
  local s = fh:read "*a"
  fh:close()
  return s
end

ok(read_src("sketchybar/top/items/spaces.lua"):find "logic.space_pill", "spaces.lua calls logic.space_pill")
ok(read_src("sketchybar/top/items/weather.lua"):find "logic.weather_label", "weather.lua calls logic.weather_label")
ok(read_src("sketchybar/top/items/volume.lua"):find "bind_popup", "volume.lua binds popup")
ok(read_src("sketchybar/top/items/volume.lua"):find "widgets.volume.slider", "volume popup has slider")
ok(read_src("sketchybar/top/items/volume.lua"):find "widgets.volume.mute", "volume popup has mute")
ok(read_src("sketchybar/top/items/calendar.lua"):find "os.date", "calendar uses local clock")
ok(read_src("sketchybar/top/items/calendar.lua"):find '%%a %%d %%b  %%H:%%M', "calendar is date next to time")
ok(read_src("sketchybar/top/items/battery.lua"):find "bind_popup", "battery.lua binds popup")
ok(read_src("sketchybar/top/items/battery.lua"):find "widgets.battery.remaining", "battery popup has remaining")
ok(read_src("sketchybar/top/items/battery.lua"):find "widgets.battery.health", "battery popup has health")
ok(read_src("sketchybar/top/items/wifi.lua"):find "bind_popup_group", "wifi.lua binds popup group")
ok(read_src("sketchybar/top/items/wifi.lua"):find "widgets.wifi.hostname", "wifi popup has hostname")
ok(read_src("sketchybar/top/items/wifi.lua"):find "widgets.wifi.ip", "wifi popup has ip")
ok(read_src("sketchybar/top/items/wifi.lua"):find "widgets.wifi.mask", "wifi popup has mask")
ok(read_src("sketchybar/top/items/wifi.lua"):find "widgets.wifi.router", "wifi popup has router")
ok(read_src("sketchybar/top/bar.lua"):find 'apply%("top"', "top bar uses shared apply")
ok(read_src("sketchybar/top/bar.lua"):find "notch_width = 0", "top bar has no notch cutout")
ok(read_src("sketchybar/bottom/bar.lua"):find 'apply "bottom"', "bottom bar still shared apply")
ok(read_src("sketchybar/settings.lua"):find "bar_embed_items = true", "items sit on the solid bar")
ok(read_src("sketchybar/island_core.lua"):find "idle_margin%(target%)", "island seeds from the top-bar strip")
ok(read_src("sketchybar/top/items/yabai_spaces.lua"):find "force = true", "space pills force visible fill")
ok(not read_src("sketchybar/top/items/init.lua"):find "nowplaying%-cli", "top bar does not use nowplaying-cli")

local island_style = require "island_style"
eq(island_style.bar().color, 0xff000000, "island bar fill is notch-black")
eq(island_style.NOTCH_BLACK, 0xff000000, "island NOTCH_BLACK constant")
eq(island_style.text(), 0xffffffff, "island text is bright on black")
eq(island_style.accent(), colors.mocha.blue, "island accent is mocha-on-black")
ok(island_style.bar().color ~= settings.theme.bar, "island fill is not the solid bar color")
eq(settings.island.y_offset_idle, -settings.island.corner_radius, "island tuck equals corner radius")
eq(settings.island.y_offset_expand, settings.island.y_offset_idle, "expand keeps the same tuck")
eq(settings.island.y_offset_external, settings.island.y_offset_idle, "external display also tucks")
eq(settings.island.idle_height, settings.bar_height - settings.island.y_offset_idle, "idle height includes tuck")
eq(settings.island.expand_height, 48 - settings.island.y_offset_expand, "expand height includes tuck")

local init_path = root .. "sketchybar/top/items/init.lua"
local f = io.open(init_path, "r")
ok(f ~= nil, "items/init.lua exists")
if f then
  local init_src = f:read "*a"
  f:close()
  ok(init_src:find 'items.yabai_spaces' or init_src:find 'items.flashspaces', "init requires spaces")
  ok(init_src:find 'require "items.calendar"', "init requires calendar")
  ok(init_src:find 'require "items.volume"', "init requires volume")
  ok(init_src:find 'require "items.battery"', "init requires battery")
  ok(init_src:find 'require "items.brew"', "init requires brew")
  ok(init_src:find 'require "items.coffee"', "init requires coffee")
  ok(init_src:find 'require "items.network"', "init requires network")
  ok(init_src:find 'require "items.wifi"', "init requires wifi")
  ok(not init_src:find 'require "items.vpn"', "init does not require vpn")
  ok(init_src:find 'require "items.bluetooth"', "init requires bluetooth")
  ok(init_src:find 'require "items.mic"', "init requires mic")
  ok(init_src:find 'require "items.ccu"', "init requires ccu")
  ok(not init_src:find 'items.media', "init does not require media")
  ok(not init_src:find 'items.logo', "init does not require logo")
  ok(not init_src:find 'items.weather', "init does not require weather")
  ok(not init_src:find "center.notch", "init has no notch spacer")
  ok(not init_src:find "bracket.left", "no left group pill — bar is the chrome")
  ok(not init_src:find "bracket.right", "no right group pill — bar is the chrome")
  ok(not init_src:find "top.group.gap", "no leftover audio/wifi pill spacer")
end

ok(not read_src("sketchybar/bottom/items/init.lua"):find "items.coffee", "bottom init does not require coffee")
ok(not read_src("sketchybar/bottom/items/init.lua"):find "items.ccu", "bottom init does not require ccu")
ok(read_src("sketchybar/bottom/items/init.lua"):find "items.vpn", "bottom init requires vpn")
ok(read_src("sketchybar/bottom/items/vpn.lua"):find("Control Center,com.apple.menuextra.vpn(7)", 1, true), "bottom vpn sits next to Control Center alias")
ok(read_src("sketchybar/bottom/items/vpn.lua"):find "widgets.vpn", "vpn name item lives on the bottom bar")
ok(read_src("sketchybar/bottom/items/init.lua"):find "items.hardware", "bottom keeps hardware")
ok(read_src("sketchybar/bottom/items/init.lua"):find "items.ssd", "bottom keeps ssd")
ok(read_src("sketchybar/bottom/items/init.lua"):find "items.uptime", "bottom keeps uptime")
ok(read_src("sketchybar/top/items/coffee.lua"):find "widgets.coffee", "coffee widget lives on the top bar")
local ccu_src = read_src("sketchybar/top/items/ccu.lua")
local grok_pos = ccu_src:find('id = "grok"', 1, true)
local cursor_pos = ccu_src:find('id = "cursor"', 1, true)
local claude_pos = ccu_src:find('id = "claude"', 1, true)
ok(grok_pos and cursor_pos and grok_pos < cursor_pos, "ccu lists grok before cursor")
ok(cursor_pos and claude_pos and cursor_pos < claude_pos, "ccu lists cursor before claude")
ok(ccu_src:find("cursor_usage.py", 1, true), "ccu fetches cursor_usage.py")
ok(ccu_src:find("bar = true", 1, true) and ccu_src:find("bar = false", 1, true), "ccu bar vs popup-only providers")
ok(read_src("sketchybar/top/items/ccu.lua"):find "widgets.ccu", "ccu widget lives on the top bar")
ok(read_src("sketchybar/top/items/ccu.lua"):find "y_offset = 1", "ccu popup opens downward")
ok(read_src("sketchybar/top/items/ccu.lua"):find "plate_w", "ccu popup width follows content")
ok(read_src("sketchybar/top/items/ccu.lua"):find "horizontal = true", "ccu popup overlays with width=0")
ok(read_src("sketchybar/top/items/ccu.lua"):find "widgets.ccu.plate", "ccu plate item sets popup width")
ok(read_src("sketchybar/top/items/ccu.lua"):find "popup_fill", "ccu popup fill is opaque")
ok(read_src("sketchybar/top/items/ccu.lua"):find 'require "ccu_logic"', "ccu item requires shipped ccu_logic")
ok(read_src("sketchybar/top/items/ccu.lua"):find "AGENT USAGE", "ccu popup headed AGENT USAGE")
ok(read_src("sketchybar/top/items/ccu.lua"):find "used · resets in", "ccu used · resets in")
ok(read_src("sketchybar/top/items/ccu.lua"):find "LAST 7 DAYS", "ccu LAST 7 DAYS")
ok(read_src("sketchybar/top/ccu_logic.lua"):find "ahead of pace", "ccu_logic ahead of pace")
ok(read_src("sketchybar/top/ccu_logic.lua"):find "behind pace", "ccu_logic behind pace")
ok(not read_src("sketchybar/top/items/ccu.lua"):find "Expected %d", "ccu popup has no Expected N% row")
ok(not read_src("sketchybar/top/items/ccu.lua"):find "Past 7d", "ccu dropped Past 7d API-$ row")
ok(not read_src("sketchybar/top/items/ccu.lua"):find "All time", "ccu dropped All time API-$ row")

local ccu_logic = require "ccu_logic"
local now = 1700000000
local claude = ccu_logic.weekly(0.31, now + 15 * 3600 + 59 * 60)
eq(ccu_logic.percent(claude.used), "31%", "ccu 31%")
eq(ccu_logic.countdown(claude.reset, now), "15h 59m", "ccu 15h 59m")
ok(ccu_logic.behind_pace(ccu_logic.weekly(0.76, now + 0.3 * ccu_logic.WEEK_SEC), now), "ccu 76% behind")
ok(not ccu_logic.behind_pace(ccu_logic.weekly(0.58, now + 0.3 * ccu_logic.WEEK_SEC), now), "ccu 58% not behind")
eq(ccu_logic.token_count(5.63e7), "56.3M", "ccu 56.3M")
eq(ccu_logic.token_count(1.86e8), "186M", "ccu 186M")
local ccu_bar = ccu_logic.bar_label({ { name = "Claude", weekly = claude } }, now)
ok(ccu_bar:find("Claude", 1, true) and ccu_bar:find("31%", 1, true) and ccu_bar:find("·", 1, true), "ccu bar chip")
ok(not ccu_bar:find("CCu", 1, true), "ccu bar is not CCu aggregate")

ok(read_src("yabai/yabairc"):find "BOTTOM_RESERVE", "yabairc has BOTTOM_RESERVE")
ok(read_src("yabai/yabairc"):find "bar_y_offset", "yabairc reads bar_y_offset")
ok(not read_src("sketchybar/theme_handler.lua"):find "if is_dark == colors.is_dark then", "theme_handler always applies system appearance")
ok(read_src("sketchybar/theme_handler.lua"):find "%-%-trigger theme_colors_updated", "theme_handler CLI-triggers when_shown items")
ok(read_src("sketchybar/theme_handler.lua"):find "sbar.delay%(0%.3", "theme_handler waits for AppleInterfaceStyle before relay")
ok(read_src("sketchybar/default.lua"):find "updates = true", "default updates=true so theme events reach items")
ok(read_src("sketchybar/colors.lua"):find "update_theme_colors%(true%)", "colors load from macOS appearance not CATPPUCCIN_TERM_MODE")
ok(not read_src("sketchybar/island/theme.lua"):find "update_theme_colors%(%)", "island relay does not revert to CATPPUCCIN_TERM_MODE")
ok(read_src("sketchybar/island/theme.lua"):find "AppleInterfaceStyle", "island theme probes macOS appearance")
ok(read_src("sketchybar/island/theme.lua"):find "probe%(%)%s*$", "island probes appearance at load")

if failures > 0 then
  print(failures .. " failed")
  os.exit(1)
end
print "all passed"
