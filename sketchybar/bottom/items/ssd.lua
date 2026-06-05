local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

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
    align = "right",
    width = 64,
    padding_right = 8,
    string = "...%",
  },
  update_freq = 600,
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.success, 0.45),
  },
})

local function free_space_color(free_percent)
  if free_percent <= 8 then
    return settings.theme.critical
  elseif free_percent <= 15 then
    return colors.orange
  elseif free_percent <= 30 then
    return settings.theme.warn
  end
  return settings.theme.success
end

ssd_volume:subscribe({ "routine", "forced", "system_woke" }, function(_)
  sbar.exec(
    [[
    df -k "$HOME" | awk 'NR==2 {
      free=$4 * 1024
      total=$2 * 1024
      pct=(total > 0) ? (free / total) * 100 : 0
      printf "%d %.1f %.1f\n", pct, free / 1024 / 1024 / 1024, total / 1024 / 1024 / 1024
    }'
  ]],
    function(output)
      if output then
        local free_pct_s = output:match "^%s*(%d+)%s+[%d%.]+%s+[%d%.]+"
        local storage = tonumber(free_pct_s) or 0
        local Icon = "󰅚"
        local Color = free_space_color(storage)
        for _, threshold in ipairs(icon_thresholds) do
          if storage >= threshold.min then
            Icon = threshold.icon
            break
          end
        end

        ssd_volume:set {
          label = {
            string = string.format("SSD %d%%", storage),
            color = Color,
          },
          icon = {
            string = Icon,
            color = Color,
          },
          background = {
            border_color = colors.with_alpha(Color, 0.45),
          },
        }
      end
    end
  )
end)
