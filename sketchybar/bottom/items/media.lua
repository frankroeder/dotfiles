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

-- Popup: [art | text column]. Text uses width=0 (stack); spacer completes the
-- column width after the control strip so the shell matches the text (no
-- double-count of controls + full TEXT_COL_W).
local ART_SIZE = cfg.popup_art_size or 180
local POPUP_H = cfg.popup_height or 240
local TEXT_COL_W = cfg.popup_text_width or 320
local text_chars = cfg.popup_text_chars or { title = 27, artist = 30, album = 30 }
local ART_GAP = 20
local PLAY_BTN = 40
local CONTROLS_Y = -56
local PLAY_FONT = "SF Pro:Regular:15.0"
local CTRL_FONT = "SF Pro:Regular:16.0"

-- back(30)+play(40)+forward(30); shuffle/repeat when media-control is present
local CTRL_STRIP = 30 + PLAY_BTN + 30
if media_control.available then
  CTRL_STRIP = CTRL_STRIP + 28 + 28
end
local SPACER_W = math.max(20, TEXT_COL_W - CTRL_STRIP)

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
    height = POPUP_H,
    background = ui.popup(),
  },
})

local is_playing = false

local function media_osascript(cmd)
  sbar.exec('osascript -e \'tell application "Music" to ' .. cmd .. "'")
end

local function after_cmd(fn)
  sbar.exec("sleep " .. tostring(delay), fn)
end

local album_art = sbar.add("item", "widgets.media.art", {
  position = "popup.widgets.media",
  icon = { drawing = false },
  label = { drawing = false },
  width = ART_SIZE,
  padding_left = 0,
  padding_right = ART_GAP,
  background = {
    drawing = false,
    height = ART_SIZE,
    corner_radius = 10,
    color = settings.theme.surface_alt,
  },
})

-- width=0 + zero pads: all text shares the same x; label.width clips to column.
local function text_row(name, font_size, max_chars, color, y)
  return sbar.add("item", name, {
    position = "popup.widgets.media",
    icon = { drawing = false },
    width = 0,
    padding_left = 0,
    padding_right = 0,
    label = {
      font = { size = font_size },
      max_chars = max_chars,
      width = TEXT_COL_W,
      padding_left = 0,
      padding_right = 0,
      color = color,
    },
    y_offset = y,
  })
end

local track_title = text_row("widgets.media.title", 22.0, text_chars.title, colors.mauve, 56)
local track_artist = text_row("widgets.media.artist", 16.0, text_chars.artist, colors.blue, 22)
local track_album = text_row("widgets.media.album", 16.0, text_chars.album, colors.lavender, -10)

local function play_icon(playing)
  if playing then
    return {
      string = icons.media.pause,
      font = PLAY_FONT,
      width = PLAY_BTN,
      align = "center",
      padding_left = 0,
      padding_right = 0,
      y_offset = 0,
      color = colors.green,
    }
  end
  return {
    string = icons.media.play,
    font = PLAY_FONT,
    width = PLAY_BTN,
    align = "center",
    padding_left = 2,
    padding_right = 0,
    y_offset = 0,
    color = colors.red,
  }
end

local shuffle_btn = sbar.add("item", "widgets.media.shuffle", {
  position = "popup.widgets.media",
  drawing = media_control.available,
  padding_left = 0,
  padding_right = 0,
  icon = {
    string = icons.media.shuffle,
    font = CTRL_FONT,
    padding_left = 4,
    padding_right = 4,
    color = colors.grey,
    highlight_color = colors.lavender,
  },
  label = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
  y_offset = CONTROLS_Y,
})

local back = sbar.add("item", "widgets.media.back", {
  position = "popup.widgets.media",
  padding_left = 0,
  padding_right = 0,
  icon = {
    string = icons.media.back,
    font = CTRL_FONT,
    padding_left = 4,
    padding_right = 4,
    color = colors.grey,
  },
  label = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
  width = 30,
  align = "center",
  background = { drawing = false },
  y_offset = CONTROLS_Y,
})

local play = sbar.add("item", "widgets.media.play", {
  position = "popup.widgets.media",
  icon = play_icon(false),
  label = {
    drawing = false,
    string = "",
    width = 0,
    padding_left = 0,
    padding_right = 0,
  },
  width = PLAY_BTN,
  padding_left = 0,
  padding_right = 0,
  align = "center",
  background = {
    height = PLAY_BTN,
    corner_radius = math.floor(PLAY_BTN / 2),
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
  padding_left = 0,
  padding_right = 0,
  icon = {
    string = icons.media.forward,
    font = CTRL_FONT,
    padding_left = 4,
    padding_right = 4,
    color = colors.grey,
  },
  label = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
  width = 30,
  align = "center",
  background = { drawing = false },
  y_offset = CONTROLS_Y,
})

local repeat_btn = sbar.add("item", "widgets.media.repeat", {
  position = "popup.widgets.media",
  drawing = media_control.available,
  padding_left = 0,
  padding_right = 0,
  icon = {
    string = icons.media.repeating,
    font = CTRL_FONT,
    highlight_color = colors.lavender,
    padding_left = 4,
    padding_right = 4,
    color = colors.grey,
  },
  label = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
  y_offset = CONTROLS_Y,
})

-- Completes the text column: controls strip + spacer ≈ TEXT_COL_W (not double).
sbar.add("item", "widgets.media.spacer", {
  position = "popup.widgets.media",
  width = SPACER_W,
  padding_left = 0,
  padding_right = 8,
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

-- sketchybar never marks popup items as "shown"; marquee while popup is open
local marquee = {
  { item = track_title, width = text_chars.title },
  { item = track_artist, width = text_chars.artist },
  { item = track_album, width = text_chars.album },
}
local marquee_running = false

local function marquee_set(entry, text)
  entry.chars = {}
  for c in (text .. "   "):gmatch(utf8.charpattern) do
    entry.chars[#entry.chars + 1] = c
  end
  entry.pos = 0
  entry.item:set {
    label = {
      string = text,
      width = TEXT_COL_W,
      padding_left = 0,
      padding_right = 0,
    },
  }
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
      m.item:set {
        label = {
          string = table.concat(win),
          width = TEXT_COL_W,
          padding_left = 0,
          padding_right = 0,
        },
      }
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
  is_playing = playing
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
    play:set { icon = play_icon(playing) }
  end)
end

local function update_album_art(path)
  if not path or path == "" then
    album_art:set { background = { drawing = false, image = { drawing = false } } }
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
    media_control.stats(function(playing, shuffle, repeat_on)
      update_track_ui(title, artist, album, playing)
      update_icons(nil, shuffle, repeat_on)
    end)
  end)
end

local function load_art()
  if media_control.available then
    media_control.update_album_art(update_album_art, {})
    return
  end
  sbar.exec("$CONFIG_DIR/helpers/get_album_art.sh", function(path)
    update_album_art(path and path:gsub("%s+$", "") or "")
  end)
end

local function refresh_all()
  if media_control.available then
    refresh_from_media_control()
  end
  load_art()
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
  load_art()
end)

media:subscribe("mouse.clicked", function()
  utils.popup_toggle(media, function()
    refresh_all()
    marquee_start()
  end)
  -- Ensure marquee runs even if popup was already open / toggle closed→open race
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
    if after then
      after_cmd(after)
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
    if media_control.available then
      media_control.stats(function(playing)
        is_playing = playing and true or false
        play:set { icon = play_icon(is_playing) }
      end)
    else
      is_playing = not is_playing
      play:set { icon = play_icon(is_playing) }
    end
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
    popup = {
      align = "center",
      horizontal = true,
      height = POPUP_H,
      background = ui.popup(),
    },
  }
  album_art:set { background = { color = settings.theme.surface_alt } }
  track_title:set { label = { color = colors.mauve, width = TEXT_COL_W, padding_left = 0, padding_right = 0 } }
  track_artist:set { label = { color = colors.blue, width = TEXT_COL_W, padding_left = 0, padding_right = 0 } }
  track_album:set { label = { color = colors.lavender, width = TEXT_COL_W, padding_left = 0, padding_right = 0 } }
  shuffle_btn:set { icon = { color = colors.grey, highlight_color = colors.lavender } }
  back:set { icon = { color = colors.grey } }
  forward:set { icon = { color = colors.grey } }
  repeat_btn:set { icon = { color = colors.grey, highlight_color = colors.lavender } }
  play:set {
    background = {
      color = colors.surface0,
      border_color = colors.surface1,
    },
    icon = play_icon(is_playing),
  }
end)
