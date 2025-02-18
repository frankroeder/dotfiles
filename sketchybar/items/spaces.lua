local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

sbar.add("event", "flashspace_workspace_change")
local map_monitor = { ["LG ULTRAFINE"] = 2, ["Built-in Retina Display"] = 1 }

local workspaces = {}

local function updateWindows(workspace_name)
  local get_windows = string.format("~/bin/flashspace list-apps %s --only-running", workspace_name)
  sbar.exec(get_windows, function(open_windows)
    local icon_line = ""
    local has_app = false
    for app in open_windows:gmatch "[^\r\n]+" do
      has_app = true
      local lookup = app_icons[app] or app_icons["Default"]
      icon_line = icon_line .. " " .. lookup
    end

    sbar.animate("tanh", settings.animation_duration, function()
      if has_app then
        workspaces[workspace_name]:set {
          label = { string = icon_line },
        }
      else
        workspaces[workspace_name]:set {
          label = { string = "" },
        }
      end
    end)
  end)
end

local function updateWorkspaceMonitor(workspace_name)
  sbar.exec("~/bin/flashspace get-display", function(display)
    display = string.gsub(display, "\n", "")
    local index = map_monitor[display]
    workspaces[workspace_name]:set {
      display = tonumber(index),
    }
  end)
end

local function parse_string_to_table(s)
  local result = {}
  for line in s:gmatch "([^\n]+)" do
    table.insert(result, line)
  end
  return result
end

local file = io.popen [[~/bin/flashspace list-workspaces]]
local wspaces = file:read "*a"
file:close()

for workspace_index, workspace_name in ipairs(parse_string_to_table(wspaces)) do
  local workspace = sbar.add("item", "workspace_" .. workspace_name, {
    icon = {
      color = colors.white,
      highlight_color = colors.blue,
      font = { family = settings.font.numbers },
      string = workspace_index - 1,
      padding_left = 8,
      padding_right = 4,
    },
    label = {
      font = "sketchybar-app-font:Regular:16.0",
      string = "",
      color = colors.grey,
      highlight_color = colors.blue,
      y_offset = -1,
      padding_right = 10,
    },
    background = {
      color = colors.bg2,
      border_width = 1,
      height = 24,
      border_color = colors.black,
    },
    padding_right = -4,
    click_script = "~/bin/flashspace workspace --name " .. workspace_name,
  })

  workspaces[workspace_name] = workspace
  updateWindows(workspace_name)
  -- updateWorkspaceMonitor(workspace_name)

  workspace:subscribe("flashspace_workspace_change", function(env)
    local focused_workspace = env.WORKSPACE
    local is_focused = focused_workspace == workspace_name
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
