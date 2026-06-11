local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local ui = require "ui"
local utils = require "utils"

sbar.add("event", "flashspace_workspace_change")

local flashspace_cmd = "flashspace"
local map_monitor = settings.monitor_map
local workspaces = {}
local workspace_state = {}
local ws_theme = settings.theme.workspace
local ws_layout = settings.spaces

local function parse_lines(output)
  local result = {}
  for line in tostring(output or ""):gmatch "[^\r\n]+" do
    if line ~= "" then
      table.insert(result, line)
    end
  end
  return result
end

local function ensureState(workspace_name)
  if not workspace_state[workspace_name] then
    workspace_state[workspace_name] = {
      focused = false,
      occupied = false,
      apps = {},
    }
  end
  return workspace_state[workspace_name]
end

local function updateStyle(workspace_name)
  local workspace = workspaces[workspace_name]
  if not workspace then
    return
  end

  local state = ensureState(workspace_name)
  local focused = state.focused

  local bg = focused and ws_theme.active_bg or ws_theme.bg
  local fg = focused and ws_theme.badge_active_text or ws_theme.active
  local border = focused and ws_theme.active_border or ws_theme.border

  sbar.animate("tanh", settings.motion.fast, function()
    workspace:set {
      icon = {
        color = fg,
        background = { drawing = false },
      },
      label = {
        color = fg,
      },
      background = {
        color = bg,
        border_width = 1,
        border_color = border,
      },
    }
  end)
end

local function updateWindows(workspace_name)
  local workspace = workspaces[workspace_name]
  if not workspace then
    return
  end

  local get_windows = flashspace_cmd
    .. " list-apps "
    .. utils.shell_quote(workspace_name)
    .. " --only-running 2>/dev/null"

  sbar.exec(get_windows, function(open_windows)
    local state = ensureState(workspace_name)
    local icon_list = {}
    state.apps = {}

    for _, app in ipairs(parse_lines(open_windows)) do
      table.insert(state.apps, app)
      table.insert(icon_list, utils.lookup_app_icon(app, app_icons))
    end

    state.occupied = #icon_list > 0
    local label_str = #icon_list > 0 and table.concat(icon_list, " ") or " —"
    workspace:set {
      label = { string = label_str },
    }
    updateStyle(workspace_name)
  end)
end

local function updateAllWindows()
  for workspace_name, _ in pairs(workspaces) do
    updateWindows(workspace_name)
  end
end

local function updateWorkspaceDisplays()
  sbar.exec(flashspace_cmd .. " list-workspaces --with-display 2>/dev/null", function(output)
    for line in tostring(output or ""):gmatch "[^\n]+" do
      local ws_name, display_name = line:match "([^,]+),%s*(.+)"
      local workspace = ws_name and workspaces[ws_name]
      if workspace and display_name then
        workspace:set {
          display = map_monitor[display_name] or "active",
        }
      end
    end
  end)
end

local list_cmd = "command -v "
  .. flashspace_cmd
  .. " >/dev/null 2>&1 && "
  .. flashspace_cmd
  .. " list-workspaces 2>/dev/null"
local file = io.popen(list_cmd)
local workspace_output = file and file:read "*a" or ""
if file then
  file:close()
end

for workspace_index, workspace_name in ipairs(parse_lines(workspace_output)) do
  local display_name = tostring(workspace_index - 1)
  local workspace = sbar.add("item", "workspace_" .. workspace_name, {
    icon = {
      color = ws_theme.empty_text,
      font = {
        family = settings.font.numbers,
        style = settings.font.style_map["Bold"],
        size = ws_layout.icon.size,
      },
      string = display_name,
      padding_left = ws_layout.icon.padding_left,
      padding_right = ws_layout.icon.padding_right,
      y_offset = ws_layout.icon.y_offset,
      background = {
        drawing = false,
        color = colors.transparent,
        border_width = 0,
        border_color = colors.transparent,
      },
    },
    label = {
      font = ws_layout.label.font,
      string = " —",
      color = ws_theme.active,
      y_offset = ws_layout.label.y_offset,
      padding_left = ws_layout.label.padding_left,
      padding_right = ws_layout.label.padding_right,
    },
    background = ui.capsule {
      color = ws_theme.bg,
      border_color = ws_theme.border,
      border_width = 1,
      height = ws_layout.capsule.height,
      corner_radius = ws_layout.capsule.corner_radius,
    },
    padding_right = ws_layout.padding,
    padding_left = ws_layout.padding,
    click_script = flashspace_cmd .. " workspace --name " .. utils.shell_quote(workspace_name),
  })

  workspaces[workspace_name] = workspace
  ensureState(workspace_name)
  updateWindows(workspace_name)

  workspace:subscribe("flashspace_workspace_change", function(env)
    local focused_workspace = env.WORKSPACE
    for name, _ in pairs(workspaces) do
      local state = ensureState(name)
      state.focused = focused_workspace == name
      updateStyle(name)
    end
    updateAllWindows()
    updateWorkspaceDisplays()
  end)
end

local observer = sbar.add("item", "widgets.flashspace_observer", {
  drawing = false,
  updates = true,
  update_freq = 3,
})

observer:subscribe({ "routine", "forced", "system_woke" }, function()
  updateAllWindows()
  updateWorkspaceDisplays()
end)

updateWorkspaceDisplays()

return workspaces
