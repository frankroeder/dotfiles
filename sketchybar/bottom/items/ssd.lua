local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local utils = require "utils"

local icon_thresholds = {
  { min = 98, icon = icons.disk["98"] },
  { min = 88, icon = icons.disk["88"] },
  { min = 76, icon = icons.disk["76"] },
  { min = 64, icon = icons.disk["64"] },
  { min = 52, icon = icons.disk["52"] },
  { min = 40, icon = icons.disk["40"] },
  { min = 28, icon = icons.disk["28"] },
  { min = 16, icon = icons.disk["16"] },
  { min = 1, icon = icons.disk["1"] },
  { min = 0, icon = icons.disk["0"] },
}

local ssd_volume = sbar.add("item", "widgets.ssd.volume", {
  position = "right",
  icon = {
    font = {
      size = 16.0,
    },
    string = icons.disk["0"],
    padding_left = 8,
  },
  label = {
    font = {
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_right = 8,
    string = "...%",
  },
  update_freq = 600,
  background = {
    drawing = true,
  },
})

ssd_volume:subscribe({ "routine", "forced", "system_woke" }, function(_)
  sbar.exec(
    [[
    osascript -e '
    tell application "Finder"
        set free_bytes to free space of startup disk
        set total_bytes to capacity of startup disk
        set occupied_percent to (((total_bytes - free_bytes) / total_bytes) * 100) as integer
        return occupied_percent
    end tell'
  ]],
    function(usedstorage)
      if usedstorage then
        local storage = tonumber(usedstorage) or 0
        local Icon = "󰅚"
        local Color = colors.white
        for _, threshold in ipairs(icon_thresholds) do
          if storage >= threshold.min then
            Icon = threshold.icon
            break
          end
        end
        Color = utils.color_gradient(storage, {
          { min = 90, color = colors.red },
          { min = 80, color = colors.orange },
          { min = 65, color = colors.yellow },
          { min = 0, color = colors.white },
        })

        ssd_volume:set {
          label = {
            string = "SSD " .. storage .. "%",
            color = Color,
          },
          icon = {
            string = Icon,
            color = Color,
          },
        }
      end
    end
  )
end)
