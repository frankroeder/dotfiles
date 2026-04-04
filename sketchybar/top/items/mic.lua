local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"
local popup_row_height = settings.ui.popup_row_height

local mic = sbar.add("item", "widgets.mic", {
  position = "right",
  icon = {
    string = icons.mic.off,
    color = settings.theme.accent_alt,
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
    border_color = colors.with_alpha(settings.theme.accent_alt, 0.45),
  },
})

local mic_slider = sbar.add("slider", "widgets.mic.slider", 100, {
  position = "popup.widgets.mic",
  slider = {
    highlight_color = settings.theme.accent_alt,
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
})

local last_volume = 100

local function update()
  sbar.exec([[osascript -e "input volume of (get volume settings)"]], function(value)
    local volume = tonumber(value) or 0
    if volume > 0 then
      last_volume = volume
    end
    local is_muted = volume == 0
    local icon = is_muted and icons.mic.off or icons.mic.on

    sbar.animate("tanh", settings.animation_duration, function()
      mic:set {
        icon = {
          string = icon,
          color = is_muted and settings.theme.critical or settings.theme.accent_alt,
        },
        label = { string = is_muted and "Muted" or volume .. "%" },
      }
    end)

    mic_slider:set { slider = { percentage = volume } }
  end)
end

local mic_mute = sbar.add("item", {
  position = "popup.widgets.mic",
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

mic_mute:subscribe("mouse.clicked", function()
  sbar.exec([[osascript -e "input volume of (get volume settings)"]], function(value)
    local volume = tonumber(value) or 0
    if volume > 0 then
      sbar.exec([[osascript -e "set volume input volume 0"]], update)
    else
      sbar.exec([[osascript -e "set volume input volume ]] .. last_volume .. [["]], update)
    end
  end)
end)

mic:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "left" then
    utils.popup_toggle(mic)
  elseif env.BUTTON == "right" then
    sbar.exec "open /System/Library/PreferencePanes/Sound.prefpane"
  end
end)

mic:subscribe("mouse.exited.global", function()
  utils.popup_hide(mic)
end)

mic_slider:subscribe("mouse.clicked", function(env)
  sbar.exec("osascript -e 'set volume input volume " .. env["PERCENTAGE"] .. "'", function()
    update()
  end)
end)

mic:subscribe({ "routine", "system_woke" }, function()
  update()
end)

update()
