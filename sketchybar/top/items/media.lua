local colors = require "colors"
local settings = require "settings"
local icons = require "icons"
local logic = require "logic"

local playpause = sbar.add("item", "center.media.playpause", {
  position = "center",
  icon = {
    string = icons.media.play,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 13,
    },
    color = colors.with_alpha(colors.blue, 0.45),
    padding_left = 4,
    padding_right = 4,
  },
  label = { drawing = false },
  background = { drawing = false },
  click_script = "nowplaying-cli togglePlayPause",
})

local artwork = sbar.add("item", "center.media.artwork", {
  position = "center",
  background = {
    image = {
      string = "",
      scale = 0.23,
      corner_radius = 4,
    },
    color = colors.transparent,
    border_width = 0,
    height = 22,
    corner_radius = 4,
  },
  icon = { drawing = false },
  label = { drawing = false },
  drawing = false,
  padding_left = 4,
  padding_right = 2,
})

local media = sbar.add("item", "center.media", {
  position = "center",
  icon = { drawing = false },
  scroll_texts = false,
  background = { drawing = false },
  label = {
    string = logic.IDLE_COPY,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 12,
    },
    color = colors.text,
    padding_left = 4,
    padding_right = 4,
  },
  popup = {
    align = "center",
    horizontal = true,
    background = {
      color = settings.theme.popup_bg,
      corner_radius = 9,
      border_width = 1,
      border_color = settings.theme.popup_border,
      height = 56,
    },
  },
  update_freq = 2,
  updates = true,
})

local popup_artwork = sbar.add("item", "popup.center.media.art", {
  position = "popup.center.media",
  background = {
    image = { string = "", scale = 0.5, corner_radius = 6 },
    color = colors.transparent,
    border_width = 0,
    height = 48,
    corner_radius = 6,
  },
  icon = { drawing = false },
  label = { drawing = false },
  drawing = false,
  padding_left = 10,
  padding_right = 6,
})

local popup_title = sbar.add("item", "popup.center.media.title", {
  position = "popup.center.media",
  icon = { drawing = false },
  label = {
    string = "",
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 13,
    },
    color = colors.text,
    padding_left = 4,
    padding_right = 4,
  },
})

local popup_artist = sbar.add("item", "popup.center.media.artist", {
  position = "popup.center.media",
  icon = { drawing = false },
  label = {
    string = "",
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 12,
    },
    color = colors.with_alpha(colors.text, 0.55),
    padding_left = 2,
    padding_right = 10,
  },
})

local popup_prev = sbar.add("item", "popup.center.media.prev", {
  position = "popup.center.media",
  icon = {
    string = icons.media.back,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 14,
    },
    color = colors.with_alpha(colors.blue, 0.85),
    padding_left = 12,
    padding_right = 8,
  },
  label = { drawing = false },
  click_script = "nowplaying-cli previous",
})

local popup_playpause = sbar.add("item", "popup.center.media.playpause", {
  position = "popup.center.media",
  icon = {
    string = icons.media.play,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 14,
    },
    color = colors.blue,
    padding_left = 8,
    padding_right = 8,
  },
  label = { drawing = false },
  click_script = "nowplaying-cli togglePlayPause",
})

local popup_next = sbar.add("item", "popup.center.media.next", {
  position = "popup.center.media",
  icon = {
    string = icons.media.forward,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 14,
    },
    color = colors.with_alpha(colors.blue, 0.85),
    padding_left = 8,
    padding_right = 12,
  },
  label = { drawing = false },
  click_script = "nowplaying-cli next",
})

local current_track_key = nil
local artwork_counter = 0
local last_label_state = nil
local last_play_state = nil
local art_dir = os.getenv "TMPDIR" or "/tmp"

local function update_track_info(title, artist)
  local key = (title or "") .. "|" .. (artist or "")
  if key == current_track_key then
    return
  end
  current_track_key = key

  popup_title:set { label = { string = title or "" } }
  popup_artist:set { label = { string = artist or "" } }

  artwork_counter = artwork_counter + 1
  local path = string.format("%s/sketchybar_art_%d.jpg", art_dir, artwork_counter)
  local cmd = string.format(
    "nowplaying-cli get artworkData 2>/dev/null | base64 -D > %q 2>/dev/null; "
      .. "if [ -s %q ]; then sips -Z 96 %q >/dev/null 2>&1; echo ok; else rm -f %q; fi",
    path,
    path,
    path,
    path
  )
  sbar.exec(cmd, function(out)
    if current_track_key ~= key then
      return
    end
    if out and tostring(out):match "ok" then
      artwork:set {
        drawing = true,
        background = { image = { drawing = true, string = path } },
        icon = { drawing = false },
      }
      popup_artwork:set {
        drawing = true,
        background = { image = { drawing = true, string = path } },
      }
    else
      artwork:set { drawing = false }
      popup_artwork:set { drawing = false }
    end
  end)
end

local function show_idle_artwork()
  artwork:set {
    drawing = true,
    background = { image = { drawing = false } },
    icon = {
      drawing = true,
      string = ":music:",
      font = {
        family = "sketchybar-app-font",
        style = "Regular",
        size = 14.0,
      },
      color = colors.with_alpha(colors.blue, 0.45),
      padding_left = 4,
      padding_right = 4,
    },
  }
end

local function clear_track_info()
  current_track_key = nil
  show_idle_artwork()
  popup_artwork:set { drawing = false }
  popup_title:set { label = { string = "" } }
  popup_artist:set { label = { string = "" } }
end

local function set_play_icon(playing)
  if playing == last_play_state then
    return
  end
  last_play_state = playing
  local glyph = playing and icons.media.pause or icons.media.play
  local color = playing and colors.blue or colors.with_alpha(colors.blue, 0.45)
  playpause:set { icon = { string = glyph, color = color } }
  popup_playpause:set { icon = { string = glyph } }
end

local function set_label(text, faded, animate)
  text = logic.pad_to(text, logic.MAX_LABEL_CHARS)
  local key = (faded and "f|" or "n|") .. text
  if key == last_label_state then
    return
  end
  last_label_state = key
  local color = faded and colors.with_alpha(colors.text, faded) or colors.text
  if animate then
    sbar.animate("tanh", 10, function()
      media:set { label = { string = text, color = color } }
    end)
  else
    media:set { label = { string = text, color = color } }
  end
end

local function set_idle()
  clear_track_info()
  set_play_icon(false)
  set_label(logic.IDLE_COPY, 0.5, true)
end

local function set_track(title, artist, playing)
  update_track_info(title, artist)
  set_play_icon(playing)
  set_label(logic.media_display(title, artist), not playing and 0.5 or false, true)
end

local function poll()
  sbar.exec("command -v nowplaying-cli >/dev/null && nowplaying-cli get playbackRate title artist || true", function(out)
    out = tostring(out or "")
    local rate_str, title, artist = out:match "([^\n]*)\n([^\n]*)\n([^\n]*)"
    local rate = tonumber(rate_str) or 0
    title = title and title:gsub("^%s*(.-)%s*$", "%1") or ""
    artist = artist and artist:gsub("^%s*(.-)%s*$", "%1") or ""
    if title ~= "" and title ~= "null" then
      set_track(title, artist, rate > 0)
    else
      set_idle()
    end
  end)
end

local function poll_after(cmd)
  sbar.exec(cmd, function()
    poll()
    sbar.exec("sleep 0.4 && true", function()
      poll()
    end)
  end)
end

local function toggle_popup()
  media:set { popup = { drawing = "toggle" } }
end

media:subscribe({ "routine", "system_woke", "deferred_wake", "media_change" }, poll)
media:subscribe("mouse.clicked", toggle_popup)
artwork:subscribe("mouse.clicked", toggle_popup)

local function optimistic_toggle()
  if last_play_state ~= nil then
    local now_playing = not last_play_state
    set_play_icon(now_playing)
    if last_label_state then
      local text = last_label_state:sub(3)
      last_label_state = nil
      set_label(text, not now_playing and 0.45 or false, false)
    end
  end
  poll_after "nowplaying-cli togglePlayPause"
end

playpause:subscribe("mouse.clicked", optimistic_toggle)
popup_playpause:subscribe("mouse.clicked", optimistic_toggle)
popup_prev:subscribe("mouse.clicked", function()
  poll_after "nowplaying-cli previous"
end)
popup_next:subscribe("mouse.clicked", function()
  poll_after "nowplaying-cli next"
end)

media:subscribe("mouse.exited.global", function()
  media:set { popup = { drawing = false } }
end)

poll()
