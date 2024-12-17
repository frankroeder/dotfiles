local colors = require "colors"
local settings = require "settings"

local swap = sbar.add("item", "widgets.swap1", {
  position = "right",
  width = 80,
  drawing = false,
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 10.0,
    },
    string = "􀂓",
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_right = 10,
    color = colors.grey,
    string = "??.? Mb",
  },
  padding_right = -4,
  update_freq = 180,
  background = {
    color = colors.lightblack,
  },
})

swap:subscribe({ "routine", "forced" }, function(env)
  sbar.exec("sysctl -n vm.swapusage | awk '{print $6}' | sed 's/M//'", function(swapstore_untrimmed)
    if swapstore_untrimmed then
      local swapstore = swapstore_untrimmed:gsub("%s*$", "")
      swapstore = swapstore:gsub(",", ".")
      local swapuse = tonumber(swapstore)

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

      local swapLabel, swapColor = formatSwapUsage(swapuse)
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
