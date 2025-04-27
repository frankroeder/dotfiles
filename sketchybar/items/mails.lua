local icons = require "icons"
local colors = require "colors"

local mail = sbar.add("item", "widgets.mail", {
  position = "left",
  drawing = false,
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
    osascript -e 'tell application "Mail"
      if it is running then
        return count of (messages of inbox whose read status is false)
      else
        return 0
      end if
    end tell'
		]],
    function(result)
      local mail_count = tonumber(result) or 0
      mail:set {
        drawing = mail_count > 0,
        label = {
          string = tostring(mail_count),
        },
        icon = {
          color = (mail_count > 0) and colors.green or colors.lightblack,
        },
      }
    end
  )
end

mail:subscribe("mouse.clicked", function()
  sbar.exec "open -a Mail"
end)

mail:subscribe("routine", function()
  update_mail_count()
end)

update_mail_count()
