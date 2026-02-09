local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local utils = require "utils"

local mic = sbar.add("item", "widgets.mic", {
  position = "right",
  icon = {
    string = icons.mic.off,
    color = colors.purple,
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

local mic_slider = sbar.add("slider", "widgets.mic.slider", 100, {
  position = "popup.widgets.mic",
  slider = {
    highlight_color = colors.purple,
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
  -- click_script = 'osascript -e "set volume input volume $PERCENTAGE"',
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
          color = is_muted and colors.red or colors.purple,
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
  width = 120,
  background = {
    corner_radius = 5,
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
