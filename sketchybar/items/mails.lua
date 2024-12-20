local icons = require "icons"
local colors = require "colors"

local mail = sbar.add("item", "widgets.mail", {
  position = "center",
  icon = {
    string = icons.mail,
    color = colors.green,
    padding_left = 8,
    y_offset = 1,
  },
  label = {
    string = "0",
    padding_right = 8,
  },
  update_freq = 180,
  background = {
    color = colors.lightblack,
    padding_left = 2,
    padding_right = 2,
  },
})

local function update_mail_count()
  sbar.exec(
    [[
        osascript -e 'tell application "Mail" to count of (messages of inbox whose read status is false)'
    ]],
    function(count)
      local mail_count = tonumber(count) or 0
      mail:set {
        label = {
          string = tostring(mail_count),
        },
        icon = {
          color = colors.green,
        },
      }
    end
  )
end

mail:subscribe("mouse.clicked", function(_)
  sbar.exec "open -a Mail"
end)

sbar.add("event", "mail_check")

mail:subscribe("mail_check", "routine", "system_woke", function(_)
  update_mail_count()
end)

update_mail_count()
