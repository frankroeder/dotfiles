local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

ActiveSpace = nil
ActiveIcon = nil
sbar.add("event", "flashspace_workspace_change")

local function parse_string_to_table(s)
  local result = {}
  for line in s:gmatch "([^\n]+)" do
    table.insert(result, line)
  end
  return result
end

local file =
  io.popen [[jq -r --arg id "$(jq -r ".selectedProfileId" ~/.config/flashspace/profiles.json)" 'first(.profiles[] | select(.id == $id)) | .workspaces[].name' ~/.config/flashspace/profiles.json]]
local workspaces = file:read "*a"
file:close()

for _, space_name in ipairs(parse_string_to_table(workspaces)) do
  local space = sbar.add("item", "workspace_" .. space_name, {
    icon = {
      color = colors.white,
      highlight_color = colors.blue,
      string = space_name,
      padding_left = 8,
      padding_right = 4,
    },
    label = {
      font = "sketchybar-app-font:Regular:16.0",
      string = "",
      color = colors.grey,
      highlight_color = colors.blue,
      y_offset = -1,
    },
    background = {
      color = colors.bg2,
      border_width = 1,
      height = 24,
      border_color = colors.black,
    },
    padding_right = -4,
  })

  space:subscribe("front_app_switched", function(env)
    if ActiveSpace == "workspace_" .. space_name then
      local has_app = false
      has_app = true
      local lookup = app_icons[env.INFO] or app_icons["Default"]
      ActiveIcon = lookup

      sbar.animate("tanh", settings.animation_duration, function()
        if has_app then
          space:set {
            label = {
              string = ActiveIcon,
              padding_right = 8,
            },
          }
        else
          space:set {
            label = {
              string = "",
              padding_right = 2,
            },
          }
        end
      end)
    else
      space:set {
        label = {
          string = "",
          padding_right = 2,
        },
      }
    end
  end)

  space:subscribe("flashspace_workspace_change", function(env)
    local selected = env.WORKSPACE == space_name
    space:set {
      icon = { highlight = selected },
      label = { highlight = selected },
      background = { border_color = selected and colors.orange or colors.bg2 },
    }
    if selected then
      ActiveSpace = env.NAME
    end
  end)
end
