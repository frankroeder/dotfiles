local colors = require "colors"
local settings = require "settings"
local ui = require "ui"

-- Native Control Center clock alias stalls the bar (screenshot/mach). Use a
-- local clock; re-enable the alias only after Screen Recording is granted:
-- sbar.add("alias", "Control Center,Clock(1)", { position = "right", padding_left = -10 })
local cal = ui.add_capsule("widgets.calendar", {
  -- Left side trimmed so battery→clock matches the ~14px widget rhythm.
  padding_left = 2,
  padding_right = 4,
  update_freq = 1,
  icon = { drawing = false },
  label = {
    color = colors.cal,
    padding_left = 4,
    padding_right = 10,
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Semibold"],
      size = 13.0,
    },
  },
  click_script = "open -a 'Calendar'",
})

cal:subscribe({ "forced", "routine", "deferred_wake" }, function()
  cal:set { label = os.date "%a %d %b  %H:%M" }
end)

cal:subscribe("theme_colors_updated", function()
  cal:set {
    background = ui.capsule(),
    label = { color = colors.cal },
  }
end)
