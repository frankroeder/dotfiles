local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local python = sbar.add("item", "widgets.python", {
  position = "right",
  update_freq = 10,
  icon = {
    string = icons.python,
    color = colors.yellow,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "0",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
  },
})

local python_popup = sbar.add("item", {
  position = "popup." .. python.name,
  label = {
    font = { size = 12.0 },
    max_chars = 60,
    string = "Checking..."
  },
  background = {
    color = colors.bg1,
    border_color = colors.black,
    border_width = 1,
    corner_radius = 5,
  }
})

python:subscribe({"routine", "system_woke"}, function()
  sbar.exec("pgrep -c -f python", function(count)
    local py_count = tonumber(count) or 0
    if py_count > 0 then
      python:set({
        label = { string = tostring(py_count) },
        drawing = true,
      })
    else
      python:set({ drawing = false })
    end
  end)
end)

python:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec("open -a Terminal .") 
  else
    python:set({ popup = { drawing = "toggle" } })
    sbar.exec("ps -eo command | grep '[p]ython' | sed 's/.*python3* //'", function(scripts)
      if scripts == "" then scripts = "No scripts found" end
      python_popup:set({ label = { string = scripts } })
    end)
  end
end)
