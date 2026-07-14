local home = os.getenv "HOME"
local dotfiles = home .. "/.dotfiles/sketchybar"

local media_control = {}

local function has_media_control()
  local h = io.popen "command -v media-control >/dev/null 2>&1 && echo yes"
  local out = h and h:read "*a" or ""
  if h then
    h:close()
  end
  return out:match "yes" ~= nil
end

media_control.available = has_media_control()

function media_control.next_track()
  sbar.exec "media-control next-track"
end

function media_control.prev_track()
  sbar.exec "media-control previous-track"
end

function media_control.toggle_play()
  sbar.exec "media-control toggle-play-pause"
end

function media_control.toggle_shuffle()
  sbar.exec "media-control toggle-shuffle"
end

function media_control.toggle_repeat()
  sbar.exec "media-control toggle-repeat"
end

function media_control.stats(callback)
  if not media_control.available then
    callback(false, false, false)
    return
  end
  sbar.exec("media-control get", function(result)
    if type(result) ~= "table" then
      callback(false, false, false)
      return
    end
    local shuffle = result.shuffle == true or result.shuffleMode == true
      or result.shuffle == "on" or result.shuffleMode == "on"
    local rep = result["repeat"] == true or result.repeatMode == true
      or result.repeating == true or result["repeat"] == "on"
    callback(result.playing == true, shuffle, rep)
  end)
end

function media_control.update_current_track(callback)
  if not media_control.available then
    callback("", "", "")
    return
  end
  sbar.exec("media-control get", function(result)
    if type(result) ~= "table" then
      callback("", "", "")
      return
    end
    callback(result.title or "", result.artist or "", result.album or "")
  end)
end

function media_control.update_album_art(callback, opts)
  opts = opts or {}
  if not media_control.available then
    callback("")
    return
  end

  local size = opts.size or 1280
  local cover = "/tmp/sketchybar_music_cover.jpg"

  sbar.exec('media-control get | jq -r ".artworkData"', function(img_data)
    if not img_data or img_data == "null\n" or img_data == "" then
      callback(opts.fallback or "")
      return
    end

    local gen = string.format('echo "%s" | base64 -d > %s', img_data:gsub("%s+$", ""), cover)
    local resize = string.format(
      'magick "%s" -resize %dx%d^ -gravity center -extent %dx%d %s 2>/dev/null || sips -z %d %d "%s" --out "%s" >/dev/null',
      cover,
      size,
      size,
      size,
      size,
      cover,
      size,
      size,
      cover,
      cover
    )
    sbar.exec(gen .. " && " .. resize, function()
      callback(cover)
    end)
  end)
end

media_control.helpers_dir = dotfiles .. "/helpers"

return media_control