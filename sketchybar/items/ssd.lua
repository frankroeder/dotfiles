local icons = require "icons"
local colors = require "colors"
local settings = require "settings"

local ssd = sbar.add("item", "widgets.ssd", {
  position = "right",
  width = 80,
  icon = {
    drawing = false,
  },
  label = {
    font = {
      style = settings.font.style_map["Bold"],
      size = 10.0,
    },
    padding_left = 0,
    padding_right = 90,
    color = colors.grey,
    string = "SSD",
    y_offset = 6,
  },
})

local ssd_volume = sbar.add("item", "widgets.ssd.volume", {
  position = "right",
  icon = {
    font = {
      size = 16.0,
    },
    string = "󰅚",
  },
  label = {
    font = {
      family = settings.font.text,
      style = "Bold",
      size = 12.0,
    },
    string = "...%",
    y_offset = -5,
  },
  update_freq = 180,
})

local ssd_padding = sbar.add("item", "widgets.ssd.padding", {
  position = "right",
  width = 40,
})

local ssd_bracket = sbar.add("bracket", "widgets.ssd.bracket", {
  ssd.name,
  ssd_volume.name,
}, {
  background = {
    color = colors.bg2,
    border_color = colors.bg1,
    border_width = 2,
  },
  popup = { align = "center", height = 30 },
})

ssd_volume:subscribe({ "routine", "forced" }, function(env)
  sbar.exec("df -H /System/Volumes/Data | awk 'END {print $5}' | sed 's/%//'", function(usedstorage)
    if usedstorage then
      local storage = tonumber(usedstorage)
      if storage >= 98 then
        Label = storage .. "%"
        Icon = "󰪥"
        Color = colors.red
      elseif storage >= 88 then
        Label = storage .. "%"
        Icon = "󰪤"
        Color = colors.orange
      elseif storage >= 76 then
        Label = storage .. "%"
        Icon = "󰪣"
        Color = colors.yellow
      elseif storage >= 64 then
        Icon = "󰪢"
        Label = storage .. "%"
      elseif storage >= 52 then
        Icon = "󰪡"
        Label = storage .. "%"
      elseif storage >= 40 then
        Icon = "󰪠"
        Label = storage .. "%"
      elseif storage >= 28 then
        Icon = "󰪟"
        Label = storage .. "%"
      elseif storage >= 16 then
        Icon = "󰪞"
        Label = storage .. "%"
      elseif storage >= 1 then
        Icon = "󰝦"
        Label = storage .. "%"
      else
        Icon = "󰅚"
        Label = "whut"
      end

      ssd_volume:set {
        label = {
          string = Label,
          color = Color,
        },
        icon = {
          string = Icon,
          color = Color,
        },
      }
    end
  end)
end)
