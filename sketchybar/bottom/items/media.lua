local settings = require "settings"
local icons = require "icons"
local app_icons = require "helpers.app_icons"
local utils = require "utils"
local ui = require "ui"

sbar.add("event", "music_change", "com.apple.Music.playerInfo")

local media = sbar.add("item", "widgets.media", {
  position = "center",
  drawing = false,
  icon = {
    font = settings.font.app_icon .. ":Regular:16.0",
    string = "",
  },
  label = {
    max_chars = 40,
    scroll_duration = 1400,
    font = { size = 14.0 },
  },
  updates = true,
  background = ui.capsule {},
  popup = {
    align = "center",
    horizontal = true,
  },
})

local function media_control(cmd)
  sbar.exec('osascript -e \'tell application "Music" to ' .. cmd .. "'")
end

local POPUP_WIDTH = 130
local ART_SIZE = 120

local album_art = sbar.add("item", "widgets.media.art", {
  position = "popup.widgets.media",
  icon = { drawing = false },
  label = { drawing = false },
  width = POPUP_WIDTH,
  background = {
    drawing = false,
    height = ART_SIZE,
    corner_radius = 8,
    color = settings.theme.surface_alt,
  },
})

local back = sbar.add("item", "widgets.media.back", {
  position = "popup.widgets.media",
  icon = {
    string = icons.media.back,
    font = { size = 16.0 },
  },
  label = { drawing = false },
  width = 90,
  align = "center",
  background = ui.button {},
})

back:subscribe("mouse.clicked", function()
  media_control "previous track"
end)

local play = sbar.add("item", "widgets.media.play", {
  position = "popup.widgets.media",
  icon = {
    string = icons.media.play_pause,
    font = { size = 16.0 },
  },
  label = { drawing = false },
  width = 90,
  align = "center",
  background = ui.button {},
})

play:subscribe("mouse.clicked", function()
  media_control "playpause"
end)

local forward = sbar.add("item", "widgets.media.forward", {
  position = "popup.widgets.media",
  icon = {
    string = icons.media.forward,
    font = { size = 16.0 },
  },
  label = { drawing = false },
  width = 90,
  align = "center",
  background = ui.button {},
})

forward:subscribe("mouse.clicked", function()
  media_control "next track"
end)

media:subscribe("music_change", function(env)
  if not env.INFO then
    return
  end

  local artist = env.INFO.Artist or ""
  local title = env.INFO.Name or ""
  local state = env.INFO["Player State"] or "Stopped"
  local display_text = artist .. " - " .. title

  sbar.animate("tanh", settings.animation_duration * 2, function()
    media:set {
      drawing = (artist .. title ~= ""),
      label = { string = display_text },
      icon = { string = app_icons["Music"] or app_icons["Default"] },
    }
    play:set {
      icon = {
        string = (state == "Playing") and icons.media.pause or icons.media.play,
      },
    }
  end)
end)

local function calculate_art_scale(width, height)
  return math.min(ART_SIZE / width, ART_SIZE / height)
end

media:subscribe("mouse.clicked", function()
  local query = media:query()
  if not query or not query.popup then
    return
  end

  local should_draw = query.popup.drawing == "off"
  media:set { popup = { drawing = should_draw } }
  if not should_draw then
    return
  end

  sbar.exec("$CONFIG_DIR/helpers/get_album_art.sh", function(album_art_path)
    local art_path = album_art_path and album_art_path:gsub("%s+$", "") or ""

    if art_path == "" then
      album_art:set { background = { drawing = false } }
      return
    end

    local sips_cmd = [[sips -g pixelWidth -g pixelHeight "]]
      .. art_path
      .. [[" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}']]
    sbar.exec(sips_cmd, function(result)
      local w, h = result:match "(%d+)%s+(%d+)"
      local width = tonumber(w) or 600
      local height = tonumber(h) or 600

      album_art:set {
        background = {
          image = {
            padding_left = settings.layout.spacing.widget,
            string = art_path,
            scale = calculate_art_scale(width, height),
          },
          drawing = true,
        },
      }
    end)
  end)
end)

media:subscribe("mouse.exited.global", function()
  utils.popup_hide(media)
end)

media:subscribe("theme_colors_updated", function()
  media:set {
    background = ui.capsule(),
    label = { color = settings.theme.text_muted },
  }
  album_art:set { background = { color = settings.theme.surface_alt } }
  back:set { background = ui.button() }
  play:set { background = ui.button() }
  forward:set { background = ui.button() }
end)
