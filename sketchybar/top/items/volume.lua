local colors = require "colors"
local icons = require "icons"
local settings = require "settings"

local volume = sbar.add("item", "widgets.volume", {
  position = "right",
  icon = {
    string = icons.volume[100],
    color = colors.blue,
    padding_left = 8,
    padding_right = 8,
    font = {
      style = settings.font.style_map["Regular"],
      size = 16.0,
    },
  },
  label = {
    string = "??%",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

local volume_slider = sbar.add("slider", "widgets.volume.slider", 100, {
  position = "popup.widgets.volume",
  slider = {
    highlight_color = colors.blue,
    background = {
      height = 6,
      corner_radius = 3,
      color = colors.bg2,
    },
    knob = {
      drawing = true,
      string = " ",
    },
  },
  background = { color = colors.bg1, height = 2, y_offset = -20 },
  click_script = 'osascript -e "set volume output volume $PERCENTAGE"',
})

local function update_volume(volume_level)
  local icon = icons.volume[0]
  local color = colors.red

  if volume_level > 66 then
    icon = icons.volume[100]
    color = colors.white
  elseif volume_level > 33 then
    icon = icons.volume[66]
    color = colors.white
  elseif volume_level > 10 then
    icon = icons.volume[33]
    color = colors.white
  elseif volume_level > 0 then
    icon = icons.volume[10]
    color = colors.white
  end

  volume:set {
    icon = { string = icon, color = color },
    label = { string = volume_level .. "%" },
  }

  volume_slider:set { slider = { percentage = volume_level } }
end

volume:subscribe("volume_change", function(env)
  update_volume(tonumber(env.INFO))
end)

volume:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "left" then
    volume:set { popup = { drawing = "toggle" } }
  elseif env.BUTTON == "right" then
    sbar.exec "open /System/Library/PreferencePanes/Sound.prefpane"
  end
end)

local volume_mute = sbar.add("item", {
  position = "popup.widgets.volume",
  align = "center",
  label = { string = "Toggle Mute", align = "center" },
  width = 120,
  background = {
    corner_radius = 5,
  },
})

volume_mute:subscribe("mouse.clicked", function()
  sbar.exec(
    "osascript -e 'set volume output muted not (output muted of (get volume settings))'",
    function()
      sbar.trigger "volume_change"
    end
  )
end)

volume:subscribe("mouse.exited.global", function()
  volume:set { popup = { drawing = false } }
end)
