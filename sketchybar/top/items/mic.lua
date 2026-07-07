local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local last_volume = 100

local mic = ui.add_capsule("widgets.mic", {
  grouped = true,
  icon = {
    string = icons.mic.off,
    color = colors.mic,
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
    color = colors.mic,
  },
  popup = { align = "right" },
})

local mic_slider = sbar.add("slider", "widgets.mic.slider", 100, {
  position = "popup.widgets.mic",
  slider = ui.slider_track(colors.mic),
  background = ui.button {},
})

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
        background = { drawing = false },
        icon = { string = icon, color = colors.mic },
        label = {
          string = is_muted and "Muted" or volume .. "%",
          color = colors.mic,
        },
      }
    end)

    mic_slider:set { slider = { percentage = volume } }
  end)
end

local mic_mute = ui.popup_button("widgets.mic.mute", mic, {
  label = "Toggle Mute",
  align = "center",
  label_align = "center",
  width = 160,
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

ui.bind_popup(mic, {
  on_right = "open /System/Library/PreferencePanes/Sound.prefpane",
})

mic_slider:subscribe("mouse.clicked", function(env)
  sbar.exec("osascript -e 'set volume input volume " .. env["PERCENTAGE"] .. "'", update)
end)

mic:subscribe({ "routine", "deferred_wake" }, update)

mic:subscribe("theme_colors_updated", function()
  mic:set { background = { drawing = false } }
  mic_slider:set {
    slider = ui.slider_track(colors.mic),
    background = ui.button(),
  }
  update()
end)

update()
