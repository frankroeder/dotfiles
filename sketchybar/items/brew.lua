local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local brew = sbar.add("item", "widgets.brew", {
  position = "right",
  icon = {
    string = icons.brew,
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
  update_freq = 1800, -- 30 mins
})

local brew_popup = sbar.add("item", {
  position = "popup." .. brew.name,
  label = {
    font = { size = 12.0 },
    string = "Checking..."
  },
  background = {
    color = colors.bg1,
    border_color = colors.black,
    border_width = 1,
    corner_radius = 5,
  }
})

brew:subscribe({ "routine", "forced", "system_woke" }, function()
  sbar.exec("brew outdated | wc -l | tr -d ' '", function(count)
    local update_count = tonumber(count) or 0
    if update_count > 0 then
      brew:set({
        label = { string = tostring(update_count) },
        drawing = true,
      })
    else
      brew:set({ drawing = false })
    end
  end)
end)

brew:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec("open -a Terminal . ; brew upgrade")
  else
    brew:set({ popup = { drawing = "toggle" } })
    sbar.exec("brew outdated", function(outdated)
      if outdated == "" then outdated = "No updates" end
      brew_popup:set({ label = { string = outdated } })
    end)
  end
end)
