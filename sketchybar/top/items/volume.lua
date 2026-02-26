local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"
local popup_row_height = settings.ui.popup_row_height

local volume = sbar.add("item", "widgets.volume", {
  position = "right",
  icon = {
    string = icons.volume[100],
    color = settings.theme.accent,
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
      style = settings.font.style_map["Semibold"],
      size = 13.0,
    },
    padding_right = 8,
    color = settings.theme.text_primary,
  },
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.accent, 0.45),
  },
})

local volume_slider = sbar.add("slider", "widgets.volume.slider", 100, {
  position = "popup.widgets.volume",
  slider = {
    highlight_color = settings.theme.accent,
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
  background = {
    color = settings.theme.surface_alt,
    height = popup_row_height,
    corner_radius = 6,
    border_width = 0,
  },
  click_script = 'osascript -e "set volume output volume $PERCENTAGE"',
})

local function update_volume(volume_level)
  local icon = icons.volume[0]
  local color = settings.theme.critical

  if volume_level > 66 then
    icon = icons.volume[100]
    color = settings.theme.text_primary
  elseif volume_level > 33 then
    icon = icons.volume[66]
    color = settings.theme.text_primary
  elseif volume_level > 10 then
    icon = icons.volume[33]
    color = settings.theme.text_primary
  elseif volume_level > 0 then
    icon = icons.volume[10]
    color = settings.theme.text_primary
  end

  sbar.animate("tanh", settings.animation_duration, function()
    volume:set {
      icon = { string = icon, color = color },
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
  background = {
    color = colors.with_alpha(settings.theme.surface_alt, 0.60),
    border_width = 0,
    corner_radius = 6,
    height = popup_row_height,
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
