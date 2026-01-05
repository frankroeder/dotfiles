local colors = require "colors"
local settings = require "settings"
local icons = require "icons"

local swap = sbar.add("item", "widgets.swap", {
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

local function formatUsedSwap(used)
  if used < 1 then
    return ""
  elseif used < 1000 then
    return string.format("%03d MB", math.floor(used))
  else
    local gb = used / 1000
    if used < 10000 then
      return string.format("%.2f GB", gb)
    else
      return string.format("%.1f GB", gb)
    end
  end
end

local function getColorByPercentage(percentage)
  if percentage < 25 then
    return colors.dirtywhite
  elseif percentage < 50 then
    return colors.yellow
  elseif percentage < 75 then
    return colors.orange
  else
    return colors.red
  end
end

swap:subscribe({ "routine", "forced" }, function(_)
  sbar.exec("sysctl -n vm.swapusage | awk '{print $3, $6}' | sed 's/M//g'", function(output)
    local total_str, used_str = output:match "(%S+)%s+(%S+)"
    if total_str and used_str then
      local total = tonumber(total_str)
      local used = tonumber(used_str)
      if total and used then
        if used < 1 then
          swap:set { drawing = false }
        else
          local percentage = (used / total) * 100
          local swapLabel = formatUsedSwap(used)
          local swapColor = getColorByPercentage(percentage)
          swap:set {
            -- displays when more than 30% of swap is used
            drawing = percentage > 30,
            label = {
              string = swapLabel .. " (" .. math.floor(percentage) .. "%)",
              color = swapColor,
            },
            icon = {
              color = swapColor,
            },
          }
        end
      end
    end
  end)
end)
