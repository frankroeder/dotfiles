local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"
local popup_row_height = settings.ui.popup_row_height

local volume = sbar.add("item", "widgets.volume", {
  position = "right",
  padding_left = settings.paddings,
  padding_right = settings.paddings,
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
  background = ui.capsule {},
})

local volume_slider = sbar.add("slider", "widgets.volume.slider", 100, {
  position = "popup.widgets.volume",
  slider = {
    highlight_color = colors.vol,
    background = {
      height = 4,
      corner_radius = 2,
      color = colors.surface0,
    },
    knob = { string = "􀀁" },
  },
  background = {
    color = settings.theme.button_bg,
    height = popup_row_height,
    corner_radius = 6,
    border_width = settings.theme.border_width,
    border_color = settings.theme.border,
  },
  click_script = 'osascript -e "set volume output volume $PERCENTAGE"',
})

local function update_volume(volume_level)
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
      icon = { string = icon, color = colors.vol },
      label = { string = volume_level .. "%" },
    }
  end)

  volume_slider:set { slider = { percentage = volume_level } }
end

volume:subscribe("volume_change", function(env)
  update_volume(tonumber(env.INFO))
end)

volume:subscribe("system_woke", function()
  sbar.exec("osascript -e 'output volume of (get volume settings)'", function(vol)
    update_volume(tonumber(vol) or 0)
  end)
end)

local volume_mute = sbar.add("item", {
  position = "popup.widgets.volume",
  align = "center",
  label = { string = "Toggle Mute", align = "center" },
  width = 160,
  background = ui.button {},
})

volume_mute:subscribe("mouse.clicked", function()
  sbar.exec(
    "osascript -e 'set volume output muted not (output muted of (get volume settings))'",
    function()
      sbar.trigger "volume_change"
    end
  )
end)

volume:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "left" then
    utils.popup_toggle(volume)
  elseif env.BUTTON == "right" then
    sbar.exec "open /System/Library/PreferencePanes/Sound.prefpane"
  end
end)

volume:subscribe("mouse.exited.global", function()
  utils.popup_hide(volume)
end)
