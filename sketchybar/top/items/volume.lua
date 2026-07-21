local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"
local utils = require "utils"

local last_level = 0
local last_muted = false
local scroll_step = settings.volume.scroll_step or 10

local volume = ui.add_capsule("widgets.volume", {
  grouped = true,
  icon = {
    string = icons.volume[100],
    color = colors.vol,
    font = {
      style = settings.font.style_map["Regular"],
      size = 16.0,
    },
  },
  label = {
    string = "??%",
    font = {
      style = settings.font.style_map["Semibold"],
      size = 13.0,
    },
    color = colors.vol,
  },
  popup = { align = "right", background = ui.popup() },
})

local volume_slider = ui.slider_popup(
  "widgets.volume.slider",
  "widgets.volume",
  colors.vol,
  'osascript -e "set volume output volume $PERCENTAGE"'
)

local function volume_icon(level, muted)
  if muted or level < 1 then
    return icons.volume[0]
  end
  if level >= 60 then
    return icons.volume[100]
  end
  if level >= 30 then
    return icons.volume[66]
  end
  return icons.volume[33]
end

local function apply_volume(level, muted)
  last_level = level or 0
  last_muted = muted and true or false
  local icon = volume_icon(last_level, last_muted)
  local label = last_muted and "Muted" or (last_level .. "%")

  sbar.animate("tanh", settings.animation_duration, function()
    volume:set {
      background = { drawing = false },
      icon = { string = icon, color = colors.vol },
      label = { string = label, color = colors.vol },
    }
  end)

  volume_slider:set {
    slider = {
      percentage = last_level,
      highlight_color = colors.vol,
    },
  }
end

local function refresh_volume()
  sbar.exec(
    [[osascript -e 'output volume of (get volume settings)' -e 'output muted of (get volume settings)']],
    function(out)
      local lines = {}
      for line in tostring(out or ""):gmatch "[^\r\n]+" do
        table.insert(lines, line)
      end
      local level = tonumber(lines[1]) or last_level
      local muted = tostring(lines[2] or ""):lower():match "true" ~= nil
      apply_volume(level, muted)
    end
  )
end

volume:subscribe("volume_change", function(env)
  local level = tonumber(env.INFO)
  if level then
    sbar.exec([[osascript -e 'output muted of (get volume settings)']], function(muted_out)
      local muted = tostring(muted_out or ""):lower():match "true" ~= nil
      apply_volume(level, muted)
    end)
  else
    refresh_volume()
  end
end)

volume:subscribe("deferred_wake", refresh_volume)

volume:subscribe("mouse.scrolled", function(env)
  local delta = utils.scroll_delta(env)
  if delta == 0 then
    return
  end
  local next = last_level + (delta > 0 and scroll_step or -scroll_step)
  if next < 0 then
    next = 0
  elseif next > 100 then
    next = 100
  end
  sbar.exec(
    "osascript -e 'set volume output volume "
      .. next
      .. "' -e 'set volume output muted false'",
    refresh_volume
  )
end)

local volume_mute = ui.popup_button("widgets.volume.mute", volume, {
  label = "Toggle Mute",
  align = "center",
  label_align = "center",
  width = 160,
})

volume_mute:subscribe("mouse.clicked", function()
  sbar.exec(
    "osascript -e 'set volume output muted not (output muted of (get volume settings))'",
    refresh_volume
  )
end)

ui.bind_popup(volume, {
  on_right = "open /System/Library/PreferencePanes/Sound.prefpane",
})

refresh_volume()

volume:subscribe("theme_colors_updated", function()
  volume:set { background = { drawing = false } }
  ui.theme_popup(volume, { buttons = { volume_mute } })
  apply_volume(last_level, last_muted)
  volume_slider:set {
    slider = ui.slider_track(colors.vol),
    background = ui.button(),
  }
end)
