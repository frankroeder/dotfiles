local colors = require "colors"
local settings = require "settings"
local icons = require "icons"
local app_icons = require "helpers.app_icons"

sbar.add("event", "music_change", "com.apple.Music.playerInfo")

local media = sbar.add("item", "widgets.media", {
  position = "center",
  drawing = false,
  icon = {
    font = "sketchybar-app-font:Regular:16.0",
    string = "",
    padding_left = 8,
  },
  label = {
    padding_right = 8,
    max_chars = 40,
    scroll_duration = 1400,
    font = {
      size = 14.0,
    },
  },
  updates = true,
  background = {
    drawing = true,
  },
  popup = {
    align = "center",
    horizontal = true,
  },
})

local function media_control(cmd)
  sbar.exec('osascript -e \'tell application "Music" to ' .. cmd .. "'")
end

local POPUP_WIDTH = 130

local album_art = sbar.add("item", "widgets.media.art", {
  position = "popup.widgets.media",
  icon = {
    drawing = false,
  },
  label = { drawing = false },
  width = POPUP_WIDTH,
  background = {
    drawing = false,
    height = 120,
    corner_radius = 8,
    color = colors.bg,
  },
})

local back = sbar.add("item", "widgets.media.back", {
  position = "popup.widgets.media",
  icon = {
    string = icons.media.back,
    font = { size = 16.0 },
  },
  label = { drawing = false },
  width = 120,
  align = "center",
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
  width = 120,
  align = "center",
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
  width = 120,
  align = "center",
})

forward:subscribe("mouse.clicked", function()
  media_control "next track"
end)

media:subscribe("music_change", function(env)
  if env.INFO then
    local artist = env.INFO.Artist or ""
    local title = env.INFO.Name or ""
    -- Access "Player State" key and handle capitalization
    local state = env.INFO["Player State"] or "Stopped"
    local display_text = artist .. " - " .. title

    sbar.animate("tanh", settings.animation_duration * 2, function()
      media:set {
        drawing = (artist .. title ~= ""),
        label = {
          string = display_text,
        },
        icon = {
          string = app_icons["Music"] or app_icons["Default"],
        },
      }

      play:set {
        icon = {
          string = (state == "Playing") and icons.media.pause or icons.media.play,
        },
      }
    end)
  end
end)

local ART_SIZE = 120

local function calculate_art_scale(width, height)
  local scale_w = ART_SIZE / width
  local scale_h = ART_SIZE / height
  return math.min(scale_w, scale_h)
end

media:subscribe("mouse.clicked", function()
  media:set { popup = { drawing = "toggle" } }

  sbar.exec("$CONFIG_DIR/helpers/get_album_art.sh", function(album_art_path)
    local art_path = album_art_path and album_art_path:gsub("%s+$", "") or ""

    if art_path ~= "" then
      -- Get image dimensions
      local sips_cmd = [[sips -g pixelWidth -g pixelHeight "]]
        .. art_path
        .. [[" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}']]
      sbar.exec(sips_cmd, function(result)
        local w, h = result:match "(%d+)%s+(%d+)"
        local width = tonumber(w) or 600
        local height = tonumber(h) or 600
        local scale = calculate_art_scale(width, height)

        album_art:set {
          background = {
            image = {
              padding_left = 5,
              string = art_path,
              scale = scale,
            },
            drawing = true,
          },
        }
      end)
    else
      album_art:set {
        background = {
          drawing = false,
        },
      }
    end
  end)
end)

media:subscribe("mouse.exited.global", function()
  media:set { popup = { drawing = false } }
end)
