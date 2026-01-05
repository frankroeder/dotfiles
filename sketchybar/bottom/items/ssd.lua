local colors = require "colors"

local icon_thresholds = {
  { min = 98, icon = "󰪥" },
  { min = 88, icon = "󰪤" },
  { min = 76, icon = "󰪣" },
  { min = 64, icon = "󰪢" },
  { min = 52, icon = "󰪡" },
  { min = 40, icon = "󰪠" },
  { min = 28, icon = "󰪟" },
  { min = 16, icon = "󰪞" },
  { min = 1, icon = "󰝦" },
  { min = 0, icon = "󰅚" },
}

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
        if storage >= 90 then
          Color = colors.red
        elseif storage >= 80 then
          Color = colors.orange
        elseif storage >= 65 then
          Color = colors.yellow
        end

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
