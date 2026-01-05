local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local ssh = sbar.add("item", "widgets.ssh", {
  position = "right",
  update_freq = 10,
  icon = {
    string = icons.ssh,
    color = colors.blue,
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

local ssh_popup = sbar.add("item", {
  position = "popup." .. ssh.name,
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

ssh:subscribe({"routine", "system_woke"}, function()
  sbar.exec("pgrep -c ssh", function(count)
    local ssh_count = tonumber(count) or 0
    if ssh_count > 0 then
      ssh:set({
        label = { string = tostring(ssh_count) },
        drawing = true,
      })
    else
      ssh:set({ drawing = false })
    end
  end)
end)

ssh:subscribe("mouse.clicked", function()
  ssh_popup:set({ label = { string = "Loading..." } })
  ssh:set({ popup = { drawing = "toggle" } })
  
  sbar.exec("ps -eo args | grep '^ssh ' | grep -v grep | sed 's/^ssh //'", function(hosts)
    if hosts == "" then hosts = "No active connections" end
    ssh_popup:set({ label = { string = hosts } })
  end)
end)
