local colors = require "colors"
local settings = require "settings"
local icons = require "icons"

local swap = sbar.add("item", "widgets.swap1", {
  position = "right",
  drawing = false,
  icon = {
    font = {
      size = 14.0,
    },
    string = icons.swap,
    padding_left = 8,
  },
  label = {
    font = {
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_right = 8,
    color = colors.grey,
    string = "??.? Mb",
  },
  update_freq = 180,
  background = {
    color = colors.lightblack,
    padding_left = 2,
    padding_right = 2,
  },
})

local function formatSwapUsage(swapuse)
  if swapuse < 1 then
    return "", colors.grey
  elseif swapuse < 100 then
    return string.format("%03d MB", math.floor(swapuse)), colors.dirtywhite
  elseif swapuse < 1000 then
    return string.format("%03d MB", math.floor(swapuse)), colors.yellow
  elseif swapuse < 2000 then
    return string.format("%.2f GB", swapuse / 1000), colors.orange
  elseif swapuse < 10000 then
    return string.format("%.2f GB", swapuse / 1000), colors.red
  else
    return string.format("%.1f GB", swapuse / 1000), colors.red
  end
end

swap:subscribe({ "routine", "forced" }, function(_)
  sbar.exec("sysctl -n vm.swapusage | awk '{print $6}' | sed 's/M//'", function(swapstore_untrimmed)
    if swapstore_untrimmed then
      local swapstore = swapstore_untrimmed:gsub("%s*$", "")
      swapstore = swapstore:gsub(",", ".")
      local swapLabel, swapColor = formatSwapUsage(tonumber(swapstore))
      if swapLabel == "" then
        swap:set { drawing = false }
      else
        swap:set {
          drawing = true,
          label = {
            string = swapLabel,
            color = swapColor,
          },
          icon = {
            color = swapColor,
          },
        }
      end
    end
  end)
end)
