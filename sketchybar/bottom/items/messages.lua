local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local apps = {
  { name = "Mattermost", icon = app_icons["Mattermost"] or ":mattermost:" },
  { name = "Signal", icon = app_icons["Signal"] or ":signal:" },
}

local messages = sbar.add("item", "widgets.messages", {
  position = "left",
  icon = {
    string = "󰍡",
    font = {
      style = settings.font.style_map["Regular"],
      size = 19.0,
    },
    color = colors.green,
  },
  label = {
    font = { family = settings.font.numbers },
    string = "",
  },
  update_freq = 30,
  drawing = false,
})

local function update_messages()
  local total_notifications = 0
  local any_unread = false
  local any_running = false

  local processed_apps = 0
  for _, app in ipairs(apps) do
    sbar.exec('pgrep -x ' .. app.name, function(pid)
      local is_running = (pid ~= "")
      if is_running then any_running = true end

      sbar.exec('lsappinfo info -only StatusLabel "' .. app.name .. '"', function(status_info)
        local label = status_info:match('"label"="([^"]*)"') or ""

        if label == "•" then
          any_unread = true
        elseif label:match("^%d+$") then
          total_notifications = total_notifications + tonumber(label)
        end

        processed_apps = processed_apps + 1
        if processed_apps == #apps then
          -- All apps checked, update the main item
          local icon_color = colors.green
          local display_label = ""

          if total_notifications > 0 then
            icon_color = colors.red
            display_label = tostring(total_notifications)
          elseif any_unread then
            icon_color = colors.yellow
            display_label = "•"
          end

          messages:set({
            icon = { color = icon_color },
            label = { string = display_label },
            drawing = any_running or (display_label ~= ""),
          })
        end
      end)
    end)
  end
end

messages:subscribe({ "routine", "system_woke" }, update_messages)

messages:subscribe("mouse.clicked", function(env)
  messages:set({ popup = { drawing = "toggle" } })
end)

messages:subscribe("mouse.exited.global", function()
  messages:set({ popup = { drawing = false } })
end)

for _, app in ipairs(apps) do
  local app_item = sbar.add("item", "widgets.messages." .. app.name:lower(), {
    position = "popup." .. messages.name,
    icon = {
      string = app.icon,
      font = "sketchybar-app-font:Regular:16.0",
      padding_left = 10,
    },
    label = {
      string = app.name,
      padding_right = 10,
    },
  })

  app_item:subscribe("mouse.clicked", function()
    sbar.exec("open -a " .. app.name)
    messages:set({ popup = { drawing = false } })
  end)
end

update_messages()
