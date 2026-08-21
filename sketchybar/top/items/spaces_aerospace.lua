local utils = require "utils"

local M = {}

M.events = { "aerospace_workspace_change", "front_app_switched" }

function M.list_workspaces_cmd()
  return "aerospace list-workspaces --all"
end

function M.fetch_state_cmd()
  return "aerospace list-windows --all --format '%{workspace}|%{app-name}' && echo '---' && aerospace list-workspaces --focused"
end

function M.click_cmd(workspace_id)
  return "aerospace workspace " .. utils.shell_quote(workspace_id)
end

function M.display_label(workspace_id)
  return workspace_id
end

return M
