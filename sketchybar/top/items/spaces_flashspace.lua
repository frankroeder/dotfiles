local utils = require "utils"

local M = {}

M.events = { "flashspace_workspace_change", "front_app_switched" }

function M.list_workspaces_cmd()
  return "flashspace list-workspaces 2>/dev/null"
end

function M.fetch_state_cmd()
  return [[
flashspace list-workspaces 2>/dev/null | while IFS= read -r ws; do
  [ -z "$ws" ] && continue
  flashspace list-apps "$ws" --only-running 2>/dev/null | while IFS= read -r app; do
    [ -n "$app" ] && printf '%s|%s\n' "$ws" "$app"
  done
done
echo '---'
flashspace get-workspace 2>/dev/null || true
]]
end

function M.click_cmd(workspace_id)
  return "flashspace workspace --name " .. utils.shell_quote(workspace_id)
end

function M.display_label(workspace_id)
  return workspace_id
end

return M
