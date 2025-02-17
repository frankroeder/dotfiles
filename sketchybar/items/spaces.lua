local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

sbar.add("event", "flashspace_workspace_change")
local map_monitor = { ["LG ULTRAFINE"] = 2, ["Built-in Retina Display"] = 1 }

local workspaces = {}

local function updateWindows(workspace_index)
  local get_windows = string.format(
    "jq -c '.profiles[].workspaces[] | select(.name == \"%s\") | {apps: [.apps[].name]}' ~/.config/flashspace/profiles.json",
    workspace_index
  )
  sbar.exec(get_windows, function(open_windows)
    local apps = open_windows.apps or {}

    local icon_line = ""
    local no_app = (#apps == 0)

    for _, app_name in ipairs(apps) do
      local lookup = app_icons[app_name]
      local icon = lookup or app_icons["Default"]
      icon_line = icon_line .. " " .. icon
    end

    sbar.animate("tanh", settings.animation_duration, function()
      if no_app then
        workspaces[workspace_index]:set {
          icon = { drawing = true },
          label = { drawing = true, string = "" },
          background = { drawing = true },
          padding_right = 1,
          padding_left = 1,
        }
      else
        workspaces[workspace_index]:set {
          icon = { drawing = true },
          label = { drawing = true, string = icon_line },
          background = { drawing = true },
          padding_right = 1,
          padding_left = 1,
        }
      end
    end)
  end)
end

local function updateWorkspaceMonitor(workspace_index)
  local query_workspaces = string.format(
    "jq -r --arg name \"%s\" '.profiles[].workspaces[] | select(.name == $name) | .display' ~/.config/flashspace/profiles.json",
    workspace_index
  )
  sbar.exec(query_workspaces, function(workspaces_and_monitors)
    workspaces_and_monitors = string.gsub(workspaces_and_monitors, "\n", "")
    local index = map_monitor[workspaces_and_monitors]
    workspaces[workspace_index]:set {
      display = tonumber(index),
    }
  end)
end

local file =
  io.popen [[jq -r --arg id "$(jq -r ".selectedProfileId" ~/.config/flashspace/profiles.json)" 'first(.profiles[] | select(.id == $id)) | .workspaces | length' ~/.config/flashspace/profiles.json]]
local ws_count = file:read "*a"
file:close()

for workspace_index = 0, tonumber(ws_count) - 1 do
  workspace_index = tonumber(workspace_index)

  local workspace = sbar.add("item", "workspace_" .. workspace_index, {
    icon = {
      color = colors.white,
      highlight_color = colors.blue,
      drawing = false,
      font = { family = settings.font.numbers },
      string = workspace_index,
      padding_left = 8,
      padding_right = 4,
    },
    label = {
      padding_right = 10,
      color = colors.grey,
      highlight_color = colors.blue,
      font = "sketchybar-app-font:Regular:16.0",
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

  workspaces[workspace_index] = workspace
  updateWindows(workspace_index)
  updateWorkspaceMonitor(workspace_index)

  workspace:subscribe("flashspace_workspace_change", function(env)
    local focused_workspace = tonumber(env.WORKSPACE)
    local is_focused = focused_workspace == workspace_index
    updateWindows(focused_workspace)
    sbar.animate("tanh", settings.animation_duration, function()
      workspace:set {
        icon = { highlight = is_focused },
        label = { highlight = is_focused },
        background = { border_color = is_focused and colors.orange or colors.bg2 },
      }
    end)
  end)

  -- workspace:subscribe("front_app_switched", function(env)
  --   local ws_index = tonumber(env.NAME:match "%d+")
  --   updateWindows(ws_index, env.INFO)
  -- end)
end

return workspaces
