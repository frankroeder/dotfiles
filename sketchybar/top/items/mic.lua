local colors = require "colors"
local icons = require "icons"
local settings = require "settings"

local mic = sbar.add("item", "widgets.mic", {
  position = "right",
  icon = {
    string = icons.mic.off,
    color = colors.purple,
    padding_left = 8,
    padding_right = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
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
    width = 120,
    background = {
      height = 6,
      corner_radius = 3,
      color = colors.bg2,
    },
    knob = {
      drawing = true,
      string = "●",
    },
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

    mic:set {
      icon = {
        string = icon,
        color = is_muted and colors.red or colors.purple,
      },
      label = { string = is_muted and "Muted" or volume .. "%" },
    }
    mic_slider:set { slider = { percentage = volume } }
  end)
end

mic:subscribe("mouse.clicked", function()
  sbar.exec([[osascript -e "input volume of (get volume settings)"]], function(value)
    local volume = tonumber(value) or 0
    if volume > 0 then
      sbar.exec([[osascript -e "set volume input volume 0"]], update)
    else
      sbar.exec([[osascript -e "set volume input volume ]] .. last_volume .. [["]], update)
    end
  end)
end)

mic:subscribe("mouse.entered", function()
  mic:set { popup = { drawing = true } }
end)

mic:subscribe("mouse.exited.global", function()
  mic:set { popup = { drawing = false } }
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
