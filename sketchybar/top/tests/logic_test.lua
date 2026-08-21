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
ok(right["widgets.bluetooth"], "right bluetooth")
ok(right["widgets.wifi"], "right wifi")
ok(right["widgets.network_up"], "right network-up")
ok(right["widgets.volume"], "right volume")
ok(right["widgets.mic"], "right mic")
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
ok(read_src("sketchybar/top/items/volume.lua"):find "logic.volume_icon", "volume.lua calls logic.volume_icon")
ok(read_src("sketchybar/top/items/battery.lua"):find "logic.battery_visual", "battery.lua calls logic.battery_visual")
ok(read_src("sketchybar/top/items/media.lua"):find "logic.media_display", "media.lua calls logic.media_display")
ok(read_src("sketchybar/top/items/weather.lua"):find "logic.weather_label", "weather.lua calls logic.weather_label")
ok(read_src("sketchybar/top/items/wifi.lua"):find "logic.wifi_connected", "wifi.lua calls logic.wifi_connected")
ok(read_src("sketchybar/top/bar.lua"):find 'apply%("top"', "top bar uses shared apply")
ok(read_src("sketchybar/top/bar.lua"):find "notch_width = 0", "top bar has no notch cutout")
ok(read_src("sketchybar/bottom/bar.lua"):find 'apply "bottom"', "bottom bar still shared apply")
ok(read_src("sketchybar/settings.lua"):find "bar_embed_items = true", "items sit on the solid bar")
ok(read_src("sketchybar/island_core.lua"):find "idle_margin%(target%)", "island seeds from the top-bar strip")

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
  ok(init_src:find 'require "items.network"', "init requires network")
  ok(init_src:find 'require "items.wifi"', "init requires wifi")
  ok(init_src:find 'require "items.bluetooth"', "init requires bluetooth")
  ok(init_src:find 'require "items.mic"', "init requires mic")
  ok(not init_src:find 'items.logo', "init does not require logo")
  ok(not init_src:find 'items.media', "init does not require media")
  ok(not init_src:find 'items.weather', "init does not require weather")
  ok(not init_src:find "center.notch", "init has no notch spacer")
  ok(not init_src:find "bracket.left", "no left group pill — bar is the chrome")
  ok(not init_src:find "bracket.right", "no right group pill — bar is the chrome")
end

ok(read_src("yabai/yabairc"):find "BOTTOM_RESERVE", "yabairc has BOTTOM_RESERVE")
ok(read_src("yabai/yabairc"):find "bar_y_offset", "yabairc reads bar_y_offset")

if failures > 0 then
  print(failures .. " failed")
  os.exit(1)
end
print "all passed"
