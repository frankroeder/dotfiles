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
    drawing = true,
  },
})

local function update_mail_count()
  sbar.exec("lsappinfo info -only StatusLabel 'Mail'", function(info)
    local count = 0
    if info then
      local label = info:match('"label"="([^"]+)"')
      if label then
        count = tonumber(label) or 0
      end
    end

    mail:set {
      drawing = count > 0,
      label = { string = tostring(count) },
      icon = {
        color = (count > 0) and colors.green or colors.lightblack,
      },
    }
  end)
end

mail:subscribe("routine", function()
  update_mail_count()
end)

update_mail_count()
