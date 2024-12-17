local colors = require "colors"
local settings = require "settings"

local ssd_volume = sbar.add("item", "widgets.ssd.volume", {
  position = "right",
  width = 55,
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
    padding_right = 8,
    string = "...%",
  },
  update_freq = 180,
  background = {
    color= colors.lightblack
  }
})

ssd_volume:subscribe({ "routine", "forced" }, function(env)
  sbar.exec("df -H /System/Volumes/Data | awk 'END {print $5}' | sed 's/%//'", function(usedstorage)
    if usedstorage then
      local storage = tonumber(usedstorage)
      local Color = colors.white
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
