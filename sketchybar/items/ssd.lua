local colors = require "colors"

local ssd_volume = sbar.add("item", "widgets.ssd.volume", {
  position = "right",
  icon = {
    font = {
      size = 16.0,
    },
    string = "󰅚",
    padding_left = 8,
  },
  label = {
    font = {
      style = "Bold",
      size = 12.0,
    },
    padding_right = 8,
    string = "...%",
  },
  update_freq = 180,
  background = {
    color = colors.lightblack,
    padding_left = 2,
    padding_right = 2,
  },
})

ssd_volume:subscribe({ "routine", "forced" }, function(_)
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
