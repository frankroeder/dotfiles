local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local ui = require "ui"
local utils = require "utils"

sbar.add("event", "layout_change")
sbar.add("event", "property_change")
sbar.add("event", "space_windows_refresh")
sbar.add("event", "window_created")
sbar.add("event", "window_destroyed")
sbar.add("event", "window_moved")
sbar.add("event", "window_minimized")
sbar.add("event", "window_deminimized")
sbar.add("event", "space_created")
sbar.add("event", "space_destroyed")

local spaces = {}
local space_state = {}

local static_names = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
local ws_theme = settings.theme.workspace
local ws_layout = settings.spaces

local refresh_in_flight = false
local refresh_queued = false
local refresh_timer_running = false
local retry_refreshes = 0

local function ensureSpaceState(index)
  if not space_state[index] then
    space_state[index] = {
      selected = false,
      visible = false,
      window_count = 0,
      display = 1,
      app_names = {},
    }
  end
  return space_state[index]
end

local function renderSpaceApps(index)
  local space = spaces[index]
  if not space then
    return
  end

  local state = ensureSpaceState(index)
  local icon_line = " —"
  if state.app_names and #state.app_names > 0 then
    local app_icon_list = {}
    for _, app in ipairs(state.app_names) do
      table.insert(app_icon_list, utils.lookup_app_icon(app, app_icons))
    end
    icon_line = " " .. table.concat(app_icon_list, " ")
  end

  space:set {
    label = { string = icon_line },
  }
end

local function updateSpaceVisual(index)
  local space = spaces[index]
  if not space then
    return
  end

  local state = ensureSpaceState(index)
  local selected = state.selected
  local occupied = (state.window_count or 0) > 0

  local bg = selected and ws_theme.active_bg
    or (occupied and ws_theme.occupied_bg or ws_theme.empty_bg)
  local fg = selected and ws_theme.badge_active_text
    or (occupied and ws_theme.occupied_text or ws_theme.empty_text)
  local border_color = selected and colors.yellow or ws_theme.border

  sbar.animate("tanh", settings.motion.fast, function()
    space:set {
      icon = {
        color = fg,
        highlight = false,
        background = { drawing = false },
      },
      label = {
        color = fg,
        highlight = false,
      },
      background = {
        drawing = true,
        color = bg,
        border_width = settings.theme.border_width,
        border_color = border_color,
      },
    }
  end)
end

local function setFocusedSpace(index)
  for idx, _ in pairs(spaces) do
    local state = ensureSpaceState(idx)
    state.selected = idx == index
    updateSpaceVisual(idx)
  end
end

local function setSpaceWindowData(index, app_names, window_count)
  local state = ensureSpaceState(index)
  state.app_names = app_names or {}
  state.window_count = window_count or 0
  renderSpaceApps(index)
  updateSpaceVisual(index)
end

local function refreshSpaceWindows()
  if refresh_in_flight then
    refresh_queued = true
    return
  end

  refresh_in_flight = true
  sbar.exec("yabai -m query --windows 2>/dev/null", function(windows)
    refresh_in_flight = false

    if type(windows) ~= "table" then
      if refresh_queued then
        refresh_queued = false
        refreshSpaceWindows()
      end
      return
    end

    local grouped = {}
    for index, _ in pairs(spaces) do
      grouped[index] = { count = 0, apps = {} }
    end

    for _, window in ipairs(windows) do
      local index = tonumber(window.space)
      local bucket = index and grouped[index]
      if bucket and not window["is-minimized"] then
        local app = tostring(window.app or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if app ~= "" then
          bucket.count = bucket.count + 1
          bucket.apps[app] = true
        end
      end
    end

    for index, bucket in pairs(grouped) do
      local app_names = {}
      for app, _ in pairs(bucket.apps) do
        table.insert(app_names, app)
      end
      table.sort(app_names)
      setSpaceWindowData(index, app_names, bucket.count)
    end

    if refresh_queued then
      refresh_queued = false
      refreshSpaceWindows()
    end
  end)
end

local function runScheduledRefresh()
  refresh_timer_running = false
  refreshSpaceWindows()

  if retry_refreshes > 0 then
    retry_refreshes = retry_refreshes - 1
    refresh_timer_running = true
    sbar.delay(0.18, runScheduledRefresh)
  end
end

local function scheduleSpaceWindowRefresh(retries, delay)
  retries = retries or 0
  if retries > retry_refreshes then
    retry_refreshes = retries
  end

  if refresh_timer_running then
    return
  end

  refresh_timer_running = true
  sbar.delay(delay or 0.08, runScheduledRefresh)
end

for index, space_name in ipairs(static_names) do
  local state = ensureSpaceState(index)
  local space = sbar.add("space", "widgets.space." .. index, {
    space = index,
    icon = {
      font = {
        family = settings.font.family,
        style = settings.font.style_map["Bold"],
        size = ws_layout.icon.size,
      },
      string = space_name,
      padding_left = ws_layout.icon.padding_left,
      padding_right = ws_layout.icon.padding_right,
      y_offset = ws_layout.icon.y_offset,
      color = ws_theme.empty_text,
      background = { drawing = false },
    },
    label = {
      padding_left = ws_layout.label.padding_left,
      padding_right = ws_layout.label.padding_right,
      color = ws_theme.active,
      font = ws_layout.label.font,
      y_offset = ws_layout.label.y_offset,
      string = " —",
    },
    padding_right = ws_layout.padding,
    padding_left = ws_layout.padding,
    background = ui.capsule {
      color = ws_theme.bg,
      border_color = ws_theme.border,
      height = ws_layout.capsule.height,
      corner_radius = ws_layout.capsule.corner_radius,
    },
  })

  spaces[index] = space

  space:subscribe("space_change", function(env)
    state.selected = env.SELECTED == "true"
    state.visible = state.selected
    updateSpaceVisual(index)
  end)

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
      sbar.exec(
        "yabai -m space --destroy " .. index .. "; sketchybar-top --trigger space_destroyed"
      )
    else
      setFocusedSpace(index)
      sbar.exec("yabai -m space --focus " .. index .. "; sketchybar-top --trigger layout_change")
    end
    scheduleSpaceWindowRefresh(0, 0.12)
  end)
end

local space_layout = sbar.add("item", "widgets.yabai_layout", {
  padding_left = settings.layout.spacing.widget,
  padding_right = settings.layout.spacing.widget,
  icon = {
    font = { family = settings.font.family },
    string = icons.yabai.bsp,
    color = ws_theme.fg,
    padding_left = ws_layout.icon.padding_left,
    padding_right = ws_layout.icon.padding_right,
  },
  label = {
    string = "",
    padding_left = settings.ui.label_padding_left,
    padding_right = settings.ui.label_padding_right,
    color = ws_theme.fg,
  },
  background = ui.capsule {
    color = ws_theme.bg,
    border_color = ws_theme.border,
    height = ws_layout.capsule.height,
    corner_radius = ws_layout.capsule.corner_radius,
  },
})

local function updateLayout()
  sbar.exec("yabai -m query --spaces 2>/dev/null", function(spaces_data)
    if type(spaces_data) ~= "table" then
      return
    end

    local present = {}
    for _, yabai_space in ipairs(spaces_data) do
      local index = tonumber(yabai_space.index)
      local display = tonumber(yabai_space.display)
      if index and spaces[index] then
        present[index] = true
        local state = ensureSpaceState(index)
        state.display = display or state.display
        state.selected = yabai_space["has-focus"] == true
        state.visible = yabai_space["is-visible"] == true
        spaces[index]:set { display = state.display, drawing = true }
        updateSpaceVisual(index)
      end
    end
    for idx, _ in pairs(spaces) do
      if not present[idx] then
        local st = ensureSpaceState(idx)
        st.selected = false
        st.visible = false
        spaces[idx]:set { drawing = false }
      end
    end

    local focused_space
    for _, yabai_space in ipairs(spaces_data) do
      if yabai_space["has-focus"] then
        focused_space = yabai_space
        break
      end
    end

    if not focused_space then
      scheduleSpaceWindowRefresh(0)
      return
    end

    local layout = focused_space.type
    local display = focused_space.display
    local stack_info = "-"

    if layout == "stack" then
      sbar.exec("yabai -m query --windows --space 2>/dev/null", function(windows)
        if type(windows) ~= "table" then
          return
        end
        local visible_count = 0
        local stack_index = nil
        for _, window in ipairs(windows) do
          if window["is-visible"] then
            visible_count = visible_count + 1
          end
          if window["has-focus"] then
            stack_index = window["stack-index"]
          end
        end

        if not stack_index or stack_index == 0 then
          stack_info = "[NA]"
        else
          stack_info = "[" .. tostring(stack_index) .. "/" .. tostring(visible_count) .. "]"
        end

        space_layout:set {
          icon = { string = icons.yabai[layout] },
          label = { string = stack_info },
          display = tonumber(display),
        }
      end)
    else
      space_layout:set {
        icon = { string = icons.yabai[layout] },
        label = { string = stack_info },
        display = tonumber(display),
      }
    end

    scheduleSpaceWindowRefresh(0)
  end)
end

local space_window_observer = sbar.add("item", "widgets.space_window_observer", {
  drawing = false,
  updates = true,
  update_freq = 3,
})

space_window_observer:subscribe("space_windows_change", function(env)
  local apps = (env.INFO and env.INFO.apps) or {}
  local app_names = {}
  local window_count = 0

  for app, count in pairs(apps) do
    window_count = window_count + count
    table.insert(app_names, app)
  end

  table.sort(app_names)

  local space_index = tonumber(env.INFO and env.INFO.space)
  if space_index and spaces[space_index] then
    setSpaceWindowData(space_index, app_names, window_count)
  end
end)

space_window_observer:subscribe("window_created", function()
  scheduleSpaceWindowRefresh(5)
end)

space_window_observer:subscribe({
  "routine",
  "forced",
  "space_windows_refresh",
  "window_destroyed",
  "window_moved",
  "window_minimized",
  "window_deminimized",
  "window_focus",
  "front_app_switched",
  "layout_change",
  "display_change",
  "space_created",
  "space_destroyed",
}, function()
  scheduleSpaceWindowRefresh(0)
end)

space_layout:subscribe("layout_change", updateLayout)
space_layout:subscribe("space_windows_refresh", updateLayout)
space_layout:subscribe("front_app_switched", updateLayout)
space_layout:subscribe("display_change", updateLayout)
space_layout:subscribe("space_created", updateLayout)
space_layout:subscribe("space_destroyed", updateLayout)

updateLayout()
scheduleSpaceWindowRefresh(2)

return spaces
