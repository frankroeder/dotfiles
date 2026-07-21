-- Now-playing bar pill. Music: music_change. Multi-app: media-control poll when installed.

local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local ui = require "ui"

sbar.add("event", "music_change", "com.apple.Music.playerInfo")

local cfg = settings.media
local BAR_ICON = app_icons["Music"] or app_icons["Default"]

local function has_media_control()
  local h = io.popen "command -v media-control >/dev/null 2>&1 && echo yes"
  local out = h and h:read "*a" or ""
  if h then
    h:close()
  end
  return out:match "yes" ~= nil
end

local mc = has_media_control()
local poll = mc and (cfg.update_freq or 15) or 0

local media = sbar.add("item", "widgets.media", {
  position = "center",
  drawing = false,
  scroll_texts = true,
  updates = true,
  update_freq = poll,
  background = ui.capsule {},
  icon = {
    font = settings.font.app_icon .. ":Regular:16.0",
    string = BAR_ICON,
    color = colors.lavender,
  },
  label = {
    max_chars = cfg.title_max_chars or 40,
    scroll_duration = 1400,
    font = { size = 14.0 },
    color = colors.lavender,
  },
})

local function apply(title, artist, playing)
  title = title or ""
  artist = artist or ""
  local has = title ~= "" or artist ~= ""
  local label = title
  if artist ~= "" and title ~= "" then
    label = artist .. " - " .. title
  elseif artist ~= "" then
    label = artist
  end
  sbar.animate("tanh", settings.animation_duration * 2, function()
    media:set {
      drawing = has,
      label = { string = label },
      icon = {
        string = BAR_ICON,
        color = playing and colors.green or colors.lavender,
      },
    }
  end)
end

local function refresh()
  if not mc then
    return
  end
  sbar.exec("media-control get", function(result)
    if type(result) ~= "table" then
      apply("", "", false)
      return
    end
    apply(result.title or "", result.artist or "", result.playing == true)
  end)
end

media:subscribe({ "routine", "deferred_wake" }, refresh)

media:subscribe("music_change", function(env)
  if not env.INFO then
    return
  end
  if mc then
    refresh()
    return
  end
  apply(
    env.INFO.Name or "",
    env.INFO.Artist or "",
    (env.INFO["Player State"] or "") == "Playing"
  )
end)

media:subscribe("mouse.clicked", function()
  if mc then
    sbar.exec "media-control toggle-play-pause"
    sbar.delay(0.2, refresh)
  else
    sbar.exec 'osascript -e \'tell application "Music" to playpause\''
  end
end)

media:subscribe("theme_colors_updated", function()
  media:set {
    background = ui.capsule(),
    label = { color = colors.lavender },
  }
  refresh()
end)

if mc then
  refresh()
end
