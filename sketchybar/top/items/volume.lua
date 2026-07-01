local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local last_level = 0

local volume = ui.add_capsule("widgets.volume", {
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
  popup = { align = "right" },
})

local volume_slider = ui.slider_popup(
  "widgets.volume.slider",
  "widgets.volume",
  colors.vol,
  'osascript -e "set volume output volume $PERCENTAGE"'
)

local function update_volume(volume_level)
  last_level = volume_level or 0
  local icon = icons.volume[0]
  if volume_level >= 60 then
    icon = icons.volume[100]
  elseif volume_level >= 30 then
    icon = icons.volume[66]
  elseif volume_level >= 1 then
    icon = icons.volume[33]
  end

  sbar.animate("tanh", settings.animation_duration, function()
    volume:set {
      background = ui.widget_background(),
      icon = { string = icon, color = colors.vol },
      label = { string = volume_level .. "%", color = colors.vol },
    }
  end)

  volume_slider:set {
    slider = {
      percentage = volume_level,
      highlight_color = colors.vol,
    },
  }
end

volume:subscribe("volume_change", function(env)
  update_volume(tonumber(env.INFO))
end)

volume:subscribe("deferred_wake", function()
  sbar.exec("osascript -e 'output volume of (get volume settings)'", function(vol)
    update_volume(tonumber(vol) or 0)
  end)
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
    function()
      sbar.trigger "volume_change"
    end
  )
end)

ui.bind_popup(volume, {
  on_right = "open /System/Library/PreferencePanes/Sound.prefpane",
})

sbar.exec("osascript -e 'output volume of (get volume settings)'", function(vol)
  update_volume(tonumber(vol) or 0)
end)

volume:subscribe("theme_colors_updated", function()
  volume:set { background = ui.widget_background() }
  update_volume(last_level)
  volume_slider:set {
    slider = ui.slider_track(colors.vol),
    background = ui.button(),
  }
  volume_mute:set { background = ui.button() }
end)
