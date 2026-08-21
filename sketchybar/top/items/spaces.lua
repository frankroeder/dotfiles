local colors = require "colors"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local utils = require "utils"
local logic = require "logic"

local function popen_ok(cmd)
  local handle = io.popen(cmd)
  local out = handle and handle:read "*a" or ""
  if handle then
    handle:close()
  end
  return out
end

local function flashspace_running()
  return popen_ok("command -v flashspace >/dev/null 2>&1 && pgrep -qx FlashSpace >/dev/null 2>&1 && echo yes"):match "yes"
end

local function aerospace_running()
  return popen_ok("command -v aerospace >/dev/null 2>&1 && pgrep -qx AeroSpace >/dev/null 2>&1 && echo yes"):match "yes"
end

local backend
if flashspace_running() then
  backend = require "items.spaces_flashspace"
elseif aerospace_running() then
  backend = require "items.spaces_aerospace"
else
  backend = require "items.spaces_yabai"
end

local builtin_events = {
  front_app_switched = true,
  routine = true,
  forced = true,
  system_woke = true,
}

for _, ev in ipairs(backend.events) do
  if not builtin_events[ev] then
    sbar.add("event", ev)
  end
end

local function exec_to_table(cmd)
  local result = popen_ok(cmd)
  local lines = {}
  for line in result:gmatch "[^\n]+" do
    lines[#lines + 1] = line
  end
  return lines
end

local function pill_theme()
  local ws = settings.theme.workspace
  return {
    focused_bg = ws.active_bg,
    unfocused_bg = colors.with_alpha(colors.surface0, colors.is_dark and 0.88 or 0.78),
    focused_text = ws.badge_active_text,
    unfocused_text = ws.occupied_text,
  }
end

local space_items = {}
local space_state = {}
local space_drawn = {}
local last_focused = ""
local update_in_flight_at = 0
local update_dirty = false
local LOCK_TIMEOUT_S = 3

local function update_all_spaces()
  local now = os.time()
  if update_in_flight_at ~= 0 and (now - update_in_flight_at) < LOCK_TIMEOUT_S then
    update_dirty = true
    return
  end
  update_in_flight_at = now

  sbar.exec(backend.fetch_state_cmd(), function(output)
    update_in_flight_at = 0
    output = tostring(output or "")

    local workspace_icons = {}
    local seen = {}
    local focused = ""
    local parsing_windows = true

    for line in output:gmatch "[^\n]+" do
      if line == "---" then
        parsing_windows = false
      elseif parsing_windows then
        local ws, app = line:match "^(.-)|(.+)$"
        if ws then
          if not workspace_icons[ws] then
            workspace_icons[ws] = ""
            seen[ws] = {}
          end
          local icon = utils.lookup_app_icon(app, app_icons)
          if not seen[ws][icon] then
            if workspace_icons[ws] == "" then
              workspace_icons[ws] = icon
            else
              workspace_icons[ws] = workspace_icons[ws] .. " " .. icon
            end
            seen[ws][icon] = true
          end
        end
      else
        focused = line:gsub("%s+", "")
      end
    end

    if focused == "" then
      focused = last_focused
    elseif focused ~= "" then
      last_focused = focused
    end

    local theme = pill_theme()
    local changed = {}
    for ws, space in pairs(space_items) do
      local icon_line = workspace_icons[ws] or ""
      local selected = ws == focused
      local key = (selected and "1|" or "0|") .. icon_line
      if space_state[ws] ~= key then
        local was_drawn = space_drawn[ws] or false
        local now_drawn = selected or icon_line ~= ""
        space_state[ws] = key
        space_drawn[ws] = now_drawn
        changed[#changed + 1] = {
          space = space,
          pill = logic.space_pill(icon_line, selected, backend.display_label(ws)),
          drawing_flipped = was_drawn ~= now_drawn,
        }
      end
    end

    if #changed > 0 then
      local to_animate = {}
      for _, c in ipairs(changed) do
        local props = logic.space_set_props(c.pill, theme)
        if c.drawing_flipped then
          c.space:set(props)
        else
          local target_color = props.background.color
          props.background = nil
          c.space:set(props)
          to_animate[#to_animate + 1] = { space = c.space, color = target_color }
        end
      end
      if #to_animate > 0 then
        sbar.animate("tanh", 8, function()
          for _, t in ipairs(to_animate) do
            t.space:set { background = { color = t.color } }
          end
        end)
      end
    end

    if update_dirty then
      update_dirty = false
      update_all_spaces()
    end
  end)
end

local workspaces = exec_to_table(backend.list_workspaces_cmd())
if #workspaces == 0 then
  workspaces = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
end

for _, workspace in ipairs(workspaces) do
  local space = sbar.add("item", "space." .. workspace:gsub("%s+", "_"), {
    position = "left",
    icon = {
      font = {
        family = settings.font.family,
        style = settings.font.style_map["Bold"],
        size = 12,
      },
      string = "",
      color = colors.text,
      padding_left = 9,
      padding_right = 9,
      y_offset = 0,
      drawing = true,
    },
    label = {
      string = "",
      font = "sketchybar-app-font:Regular:14.0",
      color = colors.text,
      padding_left = 0,
      padding_right = 0,
      y_offset = -1,
      drawing = false,
    },
    background = {
      color = colors.with_alpha(colors.surface0, 0.88),
      corner_radius = 16,
      height = 19,
      drawing = true,
    },
    padding_left = 6,
    padding_right = 0,
    drawing = false,
    click_script = backend.click_cmd(workspace),
  })
  space_items[workspace] = space
end

sbar.add("item", "spaces.right_pad", {
  position = "left",
  width = 8,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

local observer = sbar.add("item", "spaces.observer", {
  drawing = false,
  updates = true,
  update_freq = 5,
})

local subscribed = { "routine", "theme_colors_updated", "deferred_wake" }
for _, ev in ipairs(backend.events) do
  subscribed[#subscribed + 1] = ev
end

observer:subscribe(subscribed, function(env)
  if env and env.WORKSPACE and env.WORKSPACE ~= "" then
    last_focused = env.WORKSPACE
  end
  if env and env.SENDER == "theme_colors_updated" then
    space_state = {}
  end
  update_all_spaces()
end)

update_all_spaces()

return space_items
