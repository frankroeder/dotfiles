local M = {}

M.events = {
  "layout_change",
  "space_windows_refresh",
  "window_created",
  "window_destroyed",
  "window_moved",
  "window_minimized",
  "window_deminimized",
  "space_created",
  "space_destroyed",
  "display_change",
  "window_focus",
  "front_app_switched",
}

function M.list_workspaces_cmd()
  return "printf '%s\\n' 1 2 3 4 5 6 7 8 9 10"
end

function M.fetch_state_cmd()
  return table.concat({
    [[yabai -m query --windows 2>/dev/null | jq -r ]]
      .. [['.[] | select(.["is-minimized"] != true and .["is-hidden"] != true and (.app // "") != "") | "\(.space)|\(.app)"']],
    "echo '---'",
    [[yabai -m query --spaces --space 2>/dev/null | jq -r '.index // empty']],
  }, " ; ")
end

function M.click_cmd(workspace_id)
  return "yabai -m space --focus " .. tostring(workspace_id) .. " 2>/dev/null"
end

function M.display_label(workspace_id)
  return tostring(workspace_id)
end

return M
