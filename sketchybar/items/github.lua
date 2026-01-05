local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local github = sbar.add("item", "widgets.github", {
  position = "right",
  update_freq = 180,
  icon = {
    string = icons.github,
    color = colors.blue,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "?",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

local github_popup = sbar.add("item", {
  position = "popup." .. github.name,
  label = {
    font = { size = 12.0 },
    max_chars = 40,
    string = "Checking..."
  },
  background = {
    color = colors.bg1,
    border_color = colors.black,
    border_width = 1,
    corner_radius = 5,
  }
})

github:subscribe({"routine", "system_woke"}, function()
  sbar.exec("gh api notifications --q 'length'", function(count)
    local notif_count = tonumber(count) or 0
    if notif_count > 0 then
      github:set({
        label = { string = tostring(notif_count) },
        drawing = true,
      })
    else
      github:set({ drawing = false })
    end
  end)
end)

github:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec("open 'https://github.com/notifications'")
  else
    github:set({ popup = { drawing = "toggle" } })
    sbar.exec("gh api notifications --limit 5 --q '.[].subject.title'", function(titles)
      if titles == "" then titles = "No notifications" end
      github_popup:set({ label = { string = titles } })
    end)
  end
end)
