local colors = require "colors"
local icons = require "icons"
local modules = require "modules"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local media_control = require "helpers.media_control"
local utils = require "utils"
local ui = require "ui"

sbar.add("event", "music_change", "com.apple.Music.playerInfo")

local rich = modules.enabled "media_rich"
local cfg = settings.media
local delay = cfg.delay_after_cmd or 0.2

local media = sbar.add("item", "widgets.media", {
  position = "center",
  drawing = false,
  icon = {
    font = settings.font.app_icon .. ":Regular:16.0",
    string = "",
  },
  label = {
    max_chars = cfg.title_max_chars or 40,
    scroll_duration = 1400,
    font = { size = 14.0 },
    color = colors.lavender,
  },
  updates = true,
  background = ui.capsule {},
  popup = {
    align = "center",
    horizontal = rich,
    height = rich and (cfg.popup_height or 120) or nil,
  },
})

local function media_osascript(cmd)
  sbar.exec('osascript -e \'tell application "Music" to ' .. cmd .. "'")
end

local function after_cmd(fn)
  sbar.exec("sleep " .. tostring(delay), fn)
end

local POPUP_WIDTH = 130
local ART_SIZE = 120
local IMAGE_SCALE = 0.15
local Y_OFFSET = -5

local album_art = sbar.add("item", "widgets.media.art", {
  position = "popup.widgets.media",
  icon = { drawing = false },
  label = { drawing = false },
  width = rich and 0 or POPUP_WIDTH,
  padding_right = rich and 10 or 0,
  background = {
    drawing = false,
    height = ART_SIZE,
    corner_radius = 8,
    color = settings.theme.surface_alt,
    image = rich and { string = "/tmp/sketchybar_music_cover.jpg" } or nil,
  },
})

local track_title, track_artist, track_album

if rich then
  track_title = sbar.add("item", "widgets.media.title", {
    position = "popup.widgets.media",
    icon = { drawing = false },
    label = {
      font = { size = 20.0 },
      max_chars = cfg.title_max_chars or 40,
      color = colors.mauve,
    },
    y_offset = 80 + Y_OFFSET,
  })

  track_artist = sbar.add("item", "widgets.media.artist", {
    position = "popup.widgets.media",
    icon = { drawing = false },
    align = "center",
    label = {
      font = { size = 15.0 },
      max_chars = 20,
      color = colors.blue,
    },
    y_offset = 50 + Y_OFFSET,
  })

  track_album = sbar.add("item", "widgets.media.album", {
    position = "popup.widgets.media",
    icon = { drawing = false },
    label = {
      font = { size = 15.0 },
      max_chars = 20,
      color = colors.lavender,
    },
    y_offset = 25 + Y_OFFSET,
  })
end

local CONTROLS_Y = rich and (-55 + Y_OFFSET) or 0

local shuffle_btn = sbar.add("item", "widgets.media.shuffle", {
  position = "popup.widgets.media",
  drawing = rich and media_control.available,
  icon = {
    string = icons.media.shuffle,
    padding_left = 5,
    padding_right = 5,
    color = colors.grey,
    highlight_color = colors.lavender,
  },
  label = { drawing = false },
  y_offset = CONTROLS_Y,
})

local back = sbar.add("item", "widgets.media.back", {
  position = "popup.widgets.media",
  icon = {
    string = icons.media.back,
    font = { size = 16.0 },
    padding_left = 5,
    padding_right = 5,
    color = colors.grey,
  },
  label = { drawing = false },
  width = rich and 0 or 90,
  align = "center",
  background = rich and { drawing = false } or ui.button {},
  y_offset = CONTROLS_Y,
})

local play = sbar.add("item", "widgets.media.play", {
  position = "popup.widgets.media",
  icon = {
    string = icons.media.play,
    font = { size = rich and 18.0 or 16.0 },
    padding_left = rich and 4 or 0,
    padding_right = rich and 4 or 0,
    color = rich and colors.red or colors.text,
  },
  label = { drawing = false },
  width = rich and 40 or 90,
  align = "center",
  background = rich and {
    height = 40,
    corner_radius = 20,
    color = colors.surface0,
    border_color = colors.surface1,
    border_width = 2,
    drawing = true,
  } or ui.button {},
  y_offset = CONTROLS_Y,
})

local forward = sbar.add("item", "widgets.media.forward", {
  position = "popup.widgets.media",
  icon = {
    string = icons.media.forward,
    font = { size = 16.0 },
    padding_left = 5,
    padding_right = 5,
    color = colors.grey,
  },
  label = { drawing = false },
  width = rich and 0 or 90,
  align = "center",
  background = rich and { drawing = false } or ui.button {},
  y_offset = CONTROLS_Y,
})

local repeat_btn = sbar.add("item", "widgets.media.repeat", {
  position = "popup.widgets.media",
  drawing = rich and media_control.available,
  icon = {
    string = icons.media.repeating,
    highlight_color = colors.lavender,
    padding_left = 5,
    padding_right = 10,
    color = colors.grey,
  },
  label = { drawing = false },
  y_offset = CONTROLS_Y,
})

if rich then
  sbar.add("bracket", "widgets.media.controls", {
    shuffle_btn.name,
    back.name,
    play.name,
    forward.name,
    repeat_btn.name,
  }, {
    background = {
      color = colors.surface0,
      corner_radius = 11,
      drawing = true,
    },
    y_offset = CONTROLS_Y,
  })
end

local function display_artist(artist)
  if artist and artist ~= "" then
    return artist
  end
  return cfg.default_artist or "Various Artists"
end

local function display_album(album)
  if album and album ~= "" then
    return album
  end
  return cfg.default_album or "No Album"
end

local function update_track_ui(title, artist, album, state)
  local display_text = display_artist(artist)
  if title and title ~= "" then
    display_text = display_artist(artist) .. " - " .. title
  end

  local playing = state == "Playing" or state == true
  local has_media = (title and title ~= "") or (artist and artist ~= "")

  sbar.animate("tanh", settings.animation_duration * 2, function()
    media:set {
      drawing = has_media,
      label = { string = rich and (title or "") or display_text },
      icon = { string = app_icons["Music"] or app_icons["Default"] },
    }
    if track_title then
      track_title:set { label = title or "" }
      track_artist:set { label = display_artist(artist) }
      track_album:set { label = display_album(album) }
    end
    play:set {
      icon = {
        string = playing and icons.media.pause or icons.media.play,
        color = rich and (playing and colors.green or colors.red) or colors.text,
      },
    }
  end)
end

local function update_album_art(path)
  if not path or path == "" then
    album_art:set { background = { drawing = false } }
    return
  end

  if rich then
    album_art:set {
      background = {
        image = {
          string = path,
          scale = IMAGE_SCALE,
          drawing = true,
        },
        drawing = true,
      },
    }
    return
  end

  local sips_cmd = [[sips -g pixelWidth -g pixelHeight "]]
    .. path
    .. [[" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}']]
  sbar.exec(sips_cmd, function(result)
    local w, h = result:match "(%d+)%s+(%d+)"
    local width = tonumber(w) or 600
    local height = tonumber(h) or 600
    local scale = math.min(ART_SIZE / width, ART_SIZE / height)

    album_art:set {
      background = {
        image = {
          padding_left = settings.layout.spacing.widget,
          string = path,
          scale = scale,
        },
        drawing = true,
      },
    }
  end)
end

local function update_icons(_, is_shuffle, is_repeat)
  if shuffle_btn and is_shuffle ~= nil then
    shuffle_btn:set { icon = { highlight = is_shuffle } }
  end
  if repeat_btn and is_repeat ~= nil then
    repeat_btn:set { icon = { highlight = is_repeat } }
  end
end

local function refresh_from_media_control()
  media_control.update_current_track(function(title, artist, album)
    media_control.stats(function(playing)
      update_track_ui(title, artist, album, playing)
      update_icons(nil, false, false)
    end)
  end)
end

media:subscribe("routine", function()
  if media_control.available then
    refresh_from_media_control()
  end
end)

media:subscribe("music_change", function(env)
  if not env.INFO then
    return
  end
  update_track_ui(
    env.INFO.Name or "",
    env.INFO.Artist or "",
    env.INFO.Album or "",
    env.INFO["Player State"] or "Stopped"
  )
end)

local function load_art()
  if media_control.available then
    media_control.update_album_art(update_album_art, {})
    return
  end
  sbar.exec("$CONFIG_DIR/helpers/get_album_art.sh", function(path)
    update_album_art(path and path:gsub("%s+$", "") or "")
  end)
end

media:subscribe("mouse.clicked", function()
  utils.popup_toggle(media, load_art)
end)

local function control_action(action, after)
  if media_control.available then
    media_control[action]()
    after_cmd(after or refresh_from_media_control)
  else
    if action == "toggle_play" then
      media_osascript "playpause"
    elseif action == "next_track" then
      media_osascript "next track"
    elseif action == "prev_track" then
      media_osascript "previous track"
    end
  end
end

back:subscribe("mouse.clicked", function()
  control_action("prev_track", function()
    load_art()
    refresh_from_media_control()
  end)
end)

play:subscribe("mouse.clicked", function()
  control_action("toggle_play", function()
    media_control.stats(function(playing)
      play:set {
        icon = {
          string = playing and icons.media.pause or icons.media.play,
          color = rich and (playing and colors.green or colors.red) or colors.text,
        },
      }
    end)
  end)
end)

forward:subscribe("mouse.clicked", function()
  control_action("next_track", function()
    load_art()
    refresh_from_media_control()
  end)
end)

shuffle_btn:subscribe("mouse.clicked", function()
  control_action("toggle_shuffle", function()
    media_control.stats(function(_, shuffle)
      update_icons(nil, shuffle, nil)
    end)
  end)
end)

repeat_btn:subscribe("mouse.clicked", function()
  control_action("toggle_repeat", function()
    media_control.stats(function(_, _, repeat_on)
      update_icons(nil, nil, repeat_on)
    end)
  end)
end)

media:subscribe("mouse.exited.global", function()
  utils.popup_hide(media)
end)

media:subscribe("theme_colors_updated", function()
  media:set {
    background = ui.capsule(),
    label = { color = colors.lavender },
  }
  album_art:set { background = { color = settings.theme.surface_alt } }
  if not rich then
    back:set { background = ui.button() }
    play:set { background = ui.button() }
    forward:set { background = ui.button() }
  end
end)
