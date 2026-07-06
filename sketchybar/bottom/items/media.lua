local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local media_control = require "helpers.media_control"
local utils = require "utils"
local ui = require "ui"

sbar.add("event", "music_change", "com.apple.Music.playerInfo")

local cfg = settings.media
local delay = cfg.delay_after_cmd or 0.2

local media = sbar.add("item", "widgets.media", {
  position = "center",
  drawing = false,
  scroll_texts = true,
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
    horizontal = true,
    height = cfg.popup_height or 160,
  },
})

local function media_osascript(cmd)
  sbar.exec('osascript -e \'tell application "Music" to ' .. cmd .. "'")
end

local function after_cmd(fn)
  sbar.exec("sleep " .. tostring(delay), fn)
end

local ART_SIZE = 120

local album_art = sbar.add("item", "widgets.media.art", {
  position = "popup.widgets.media",
  icon = { drawing = false },
  label = { drawing = false },
  width = ART_SIZE,
  padding_right = 12,
  background = {
    drawing = false,
    height = ART_SIZE,
    corner_radius = 8,
    color = settings.theme.surface_alt,
  },
})

-- width = 0 + zero paddings keep all text items at the same x, stacked via y_offset
local track_title = sbar.add("item", "widgets.media.title", {
  position = "popup.widgets.media",
  icon = { drawing = false },
  width = 0,
  padding_left = 0,
  padding_right = 0,
  label = {
    font = { size = 20.0 },
    max_chars = 18,
    color = colors.mauve,
  },
  y_offset = 48,
})

local track_artist = sbar.add("item", "widgets.media.artist", {
  position = "popup.widgets.media",
  icon = { drawing = false },
  width = 0,
  padding_left = 0,
  padding_right = 0,
  label = {
    font = { size = 15.0 },
    max_chars = 20,
    color = colors.blue,
  },
  y_offset = 18,
})

local track_album = sbar.add("item", "widgets.media.album", {
  position = "popup.widgets.media",
  icon = { drawing = false },
  width = 0,
  padding_left = 0,
  padding_right = 0,
  label = {
    font = { size = 15.0 },
    max_chars = 20,
    color = colors.lavender,
  },
  y_offset = -8,
})

local CONTROLS_Y = -48

local shuffle_btn = sbar.add("item", "widgets.media.shuffle", {
  position = "popup.widgets.media",
  drawing = media_control.available,
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
  width = 30,
  align = "center",
  background = { drawing = false },
  y_offset = CONTROLS_Y,
})

local play = sbar.add("item", "widgets.media.play", {
  position = "popup.widgets.media",
  -- Icon box, item box and background must all be exactly 40px with zero
  -- paddings (item and background paddings are coupled in sketchybar), or the
  -- circle offsets from the glyph. The asymmetric icon paddings and y_offset
  -- optically re-center the SF glyphs (their ink sits left/high of the
  -- advance box that sketchybar centers on).
  icon = {
    string = icons.media.play,
    font = { size = 18.0 },
    width = 40,
    align = "center",
    padding_left = 4,
    padding_right = 0,
    y_offset = -1,
    color = colors.red,
  },
  label = { drawing = false },
  width = 40,
  align = "center",
  background = {
    height = 40,
    corner_radius = 20,
    color = colors.surface0,
    border_color = colors.surface1,
    border_width = 2,
    drawing = true,
    padding_left = 0,
    padding_right = 0,
  },
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
  width = 30,
  align = "center",
  background = { drawing = false },
  y_offset = CONTROLS_Y,
})

local repeat_btn = sbar.add("item", "widgets.media.repeat", {
  position = "popup.widgets.media",
  drawing = media_control.available,
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

-- pads the text/controls column so long titles stay inside the popup
sbar.add("item", "widgets.media.spacer", {
  position = "popup.widgets.media",
  width = 60,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

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

-- sketchybar never marks popup items as "shown", so scroll_texts is dead there;
-- scroll the popup texts manually while the popup is open
local marquee = {
  { item = track_title, width = 18 },
  { item = track_artist, width = 20 },
  { item = track_album, width = 20 },
}
local marquee_running = false

local function marquee_set(entry, text)
  entry.chars = {}
  for c in (text .. "   "):gmatch(utf8.charpattern) do
    entry.chars[#entry.chars + 1] = c
  end
  entry.pos = 0
  entry.item:set { label = text }
end

local function marquee_tick()
  if media:query().popup.drawing ~= "on" then
    marquee_running = false
    return
  end
  for _, m in ipairs(marquee) do
    if m.chars and #m.chars - 3 > m.width then
      local win = {}
      for i = 0, m.width - 1 do
        win[i + 1] = m.chars[(m.pos + i) % #m.chars + 1]
      end
      m.pos = (m.pos + 1) % #m.chars
      m.item:set { label = table.concat(win) }
    end
  end
  sbar.delay(0.3, marquee_tick)
end

local function marquee_start()
  if not marquee_running then
    marquee_running = true
    marquee_tick()
  end
end

local function update_track_ui(title, artist, album, state)
  local playing = state == "Playing" or state == true
  local has_media = (title and title ~= "") or (artist and artist ~= "")

  sbar.animate("tanh", settings.animation_duration * 2, function()
    media:set {
      drawing = has_media,
      label = { string = title or "" },
      icon = { string = app_icons["Music"] or app_icons["Default"] },
    }
    marquee_set(marquee[1], title or "")
    marquee_set(marquee[2], display_artist(artist))
    marquee_set(marquee[3], display_album(album))
    play:set {
      icon = {
        string = playing and icons.media.pause or icons.media.play,
        color = playing and colors.green or colors.red,
      },
    }
  end)
end

local function update_album_art(path)
  if not path or path == "" then
    album_art:set { background = { drawing = false } }
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
  marquee_start()
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
          color = playing and colors.green or colors.red,
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
  track_title:set { label = { color = colors.mauve } }
  track_artist:set { label = { color = colors.blue } }
  track_album:set { label = { color = colors.lavender } }
  shuffle_btn:set { icon = { color = colors.grey, highlight_color = colors.lavender } }
  back:set { icon = { color = colors.grey } }
  forward:set { icon = { color = colors.grey } }
  repeat_btn:set { icon = { color = colors.grey, highlight_color = colors.lavender } }
  play:set { background = { color = colors.surface0, border_color = colors.surface1 } }
end)
