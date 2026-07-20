local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local ui = require "ui"
local utils = require "utils"

sbar.add("event", "layout_change")
sbar.add("event", "space_windows_refresh")
sbar.add("event", "window_created")
sbar.add("event", "window_destroyed")
sbar.add("event", "window_moved")
sbar.add("event", "window_minimized")
sbar.add("event", "window_deminimized")
sbar.add("event", "space_created")
sbar.add("event", "space_destroyed")
sbar.add("event", "display_change")
sbar.add("event", "window_focus")

local spaces = {}
local space_state = {}
-- Declared early: set_layout_item / update* close over this local (not a global).
local space_layout

local static_names = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
local ws_layout = settings.spaces
local max_app_icons = 5
local motion_fast = settings.motion.fast

-- Layout pill accent (live palette): stack=mauve, bsp=blue, float=peach.
local function layout_accent(layout)
  if layout == "stack" then
    return colors.mauve
  end
  if layout == "float" then
    return colors.peach
  end
  return colors.blue
end

local function ws_theme()
  return settings.theme.workspace
end

-- Selection = solid active fill (no ring). Rings were hard to see and clashed.
local function space_surface(state)
  local theme = ws_theme()
  local bg
  if state.selected then
    bg = theme.active_bg
  elseif state.visible then
    bg = theme.visible_bg or theme.occupied_bg
  elseif (state.window_count or 0) > 0 then
    bg = theme.occupied_bg
  else
    bg = theme.empty_bg
  end
  return ui.widget_background {
    color = bg,
    border_width = 0,
    border_color = colors.transparent,
    height = ws_layout.capsule.height,
    corner_radius = ws_layout.capsule.corner_radius,
  }
end

-- Calendar/battery shell; layout type only tints border + glyph/label.
local function layout_surface(accent)
  local tint = accent or settings.theme.accent
  local dark = colors.is_dark
  return ui.widget_background {
    color = settings.theme.surface,
    border_color = colors.with_alpha(tint, dark and 0.45 or 0.50),
    border_width = settings.theme.border_width,
    height = ws_layout.capsule.height,
    corner_radius = ws_layout.capsule.corner_radius,
  }
end

local refresh_in_flight = false
local refresh_queued = false
local refresh_timer_running = false
local retry_refreshes = 0
local layout_in_flight = false
local layout_queued = false

local function ensureSpaceState(index)
  if not space_state[index] then
    space_state[index] = {
      selected = false,
      visible = false,
      window_count = 0,
      display = 1,
      app_names = {},
      last_icon_line = nil,
      last_visual = nil,
    }
  end
  return space_state[index]
end

-- Same fg ladder as flashspaces (theme.workspace tokens only).
local function badge_color_for(state)
  local theme = ws_theme()
  if state.selected then
    return theme.badge_active_text
  end
  if (state.window_count or 0) > 0 then
    return theme.occupied_text
  end
  if state.visible then
    return theme.occupied_text
  end
  return theme.empty_text
end

local function apps_color_for(state)
  return badge_color_for(state)
end

local function renderSpaceApps(index, animate)
  local space = spaces[index]
  if not space then
    return
  end

  local state = ensureSpaceState(index)
  local icon_line = " —"
  if state.app_names and #state.app_names > 0 then
    local app_icon_list = {}
    for _, app in ipairs(state.app_names) do
      if type(app) == "string" and app ~= "" and #app_icon_list < max_app_icons then
        table.insert(app_icon_list, utils.lookup_app_icon(app, app_icons))
      end
    end
    if #app_icon_list > 0 then
      icon_line = " " .. table.concat(app_icon_list, " ")
      if #state.app_names > max_app_icons then
        icon_line = icon_line .. "…"
      end
    end
  end

  local apps_color = apps_color_for(state)
  local key = icon_line .. "|" .. tostring(apps_color)
  if state.last_icon_line == key then
    return
  end
  state.last_icon_line = key

  local payload = {
    label = {
      string = icon_line,
      color = apps_color,
      y_offset = ws_layout.label.y_offset,
    },
  }
  if animate == false then
    space:set(payload)
    return
  end
  sbar.animate("tanh", motion_fast, function()
    space:set(payload)
  end)
end

local function updateSpaceVisual(index, opts)
  opts = opts or {}
  local space = spaces[index]
  if not space then
    return
  end

  local state = ensureSpaceState(index)
  local selected = state.selected
  local occupied = (state.window_count or 0) > 0
  local fg = badge_color_for(state)
  local surface = space_surface(state)
  local key = table.concat({
    selected and "1" or "0",
    state.visible and "1" or "0",
    occupied and "1" or "0",
    tostring(fg),
    tostring(surface.color),
  }, "|")

  if state.last_visual == key and not opts.force then
    return
  end
  state.last_visual = key

  sbar.animate("tanh", motion_fast, function()
    space:set {
      icon = {
        color = fg,
        highlight = false,
        y_offset = ws_layout.icon.y_offset,
        background = { drawing = false },
      },
      label = {
        color = apps_color_for(state),
        highlight = false,
      },
      background = surface,
    }
  end)
end

local function setFocusedSpace(index)
  for idx, _ in pairs(spaces) do
    local state = ensureSpaceState(idx)
    local was = state.selected
    state.selected = idx == index
    if was ~= state.selected then
      state.last_visual = nil
      state.last_icon_line = nil
      updateSpaceVisual(idx)
      renderSpaceApps(idx, false)
    end
  end
end

-- Skip no-op focus; silence yabai stderr (already-focused / missing index).
local function focus_space(index)
  if ensureSpaceState(index).selected then
    return
  end
  setFocusedSpace(index)
  sbar.exec("yabai -m space --focus " .. index .. " 2>/dev/null")
end

local function setSpaceWindowData(index, app_names, window_count)
  local state = ensureSpaceState(index)
  local prev_count = state.window_count
  state.app_names = app_names or {}
  state.window_count = window_count or 0
  if prev_count ~= state.window_count then
    state.last_visual = nil
  end
  renderSpaceApps(index, true)
  updateSpaceVisual(index)
end

local function window_counts(windows)
  local grouped = {}
  for index, _ in pairs(spaces) do
    grouped[index] = { count = 0, apps = {} }
  end

  for _, window in ipairs(windows) do
    local index = tonumber(window.space)
    local bucket = index and grouped[index]
    if bucket and not window["is-minimized"] and window["is-hidden"] ~= true then
      local app = tostring(window.app or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if app ~= "" then
        bucket.count = bucket.count + 1
        bucket.apps[app] = true
      end
    end
  end
  return grouped
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

    local grouped = window_counts(windows)
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
    sbar.delay(0.2, runScheduledRefresh)
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

-- yabai 7.x stack layout often reports stack-index=0 for every window.
-- Fall back to focused position among non-minimized windows on the space.
local function format_stack_label(windows)
  local entries = {}
  local focused_pos = nil
  local stack_idx = nil

  for _, window in ipairs(windows) do
    if not window["is-minimized"] and window["is-hidden"] ~= true then
      table.insert(entries, window)
      local si = tonumber(window["stack-index"]) or 0
      if window["has-focus"] then
        focused_pos = #entries
        if si > 0 then
          stack_idx = si
        end
      end
    end
  end

  local total = #entries
  if total <= 1 then
    return ""
  end

  local pos = stack_idx or focused_pos
  if not pos then
    return tostring(total)
  end
  return string.format("%d/%d", pos, total)
end

local last_layout_key = nil

local function set_layout_item(layout, label, display)
  if not space_layout then
    return
  end
  local glyph = icons.yabai[layout] or icons.yabai.bsp
  local text = label or ""
  local has_label = text ~= ""
  -- Label off → its padding_right is gone; keep icon solo padded like left side.
  local icon_pad_r = has_label and ws_layout.icon.padding_right or ws_layout.icon.padding_left
  local tint = layout_accent(layout)
  local key = layout .. "|" .. text .. "|" .. tostring(display) .. "|" .. tostring(tint)
  if key == last_layout_key then
    return
  end
  last_layout_key = key

  sbar.animate("tanh", motion_fast, function()
    space_layout:set {
      icon = {
        string = glyph,
        color = tint,
        padding_right = icon_pad_r,
      },
      label = {
        string = text,
        color = tint,
        drawing = has_label,
      },
      background = layout_surface(tint),
      display = tonumber(display),
    }
  end)
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
      color = ws_theme().empty_text,
      background = { drawing = false },
    },
    label = {
      padding_left = ws_layout.label.padding_left,
      padding_right = ws_layout.label.padding_right,
      color = ws_theme().active,
      font = ws_layout.label.font,
      y_offset = ws_layout.label.y_offset,
      string = " —",
    },
    padding_right = ws_layout.padding,
    padding_left = ws_layout.padding,
    background = space_surface(state),
  })

  spaces[index] = space

  space:subscribe("mouse.entered", function()
    local st = ensureSpaceState(index)
    if st.selected then
      return
    end
    sbar.animate("tanh", motion_fast, function()
      space:set {
        background = ui.widget_background {
          color = ws_theme().hover_bg,
          border_width = 0,
          border_color = colors.transparent,
          height = ws_layout.capsule.height,
          corner_radius = ws_layout.capsule.corner_radius,
        },
      }
    end)
  end)

  space:subscribe("mouse.exited", function()
    ensureSpaceState(index).last_visual = nil
    updateSpaceVisual(index, { force = true })
  end)

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
      -- Only destroy empty spaces (avoids nuking occupied ones by misclick).
      local st = ensureSpaceState(index)
      if (st.window_count or 0) == 0 then
        sbar.exec("yabai -m space --destroy " .. index .. " 2>/dev/null")
      else
        focus_space(index)
      end
    else
      focus_space(index)
    end
    scheduleSpaceWindowRefresh(0, 0.12)
  end)
end

space_layout = sbar.add("item", "widgets.yabai_layout", {
  padding_left = settings.layout.spacing.widget,
  padding_right = settings.layout.spacing.widget,
  icon = {
    font = { family = settings.font.family },
    string = icons.yabai.bsp,
    color = colors.blue,
    padding_left = ws_layout.icon.padding_left,
    padding_right = ws_layout.icon.padding_right,
  },
  label = {
    string = "",
    drawing = false,
    padding_left = settings.ui.label_padding_left,
    padding_right = settings.ui.label_padding_right,
    color = colors.blue,
  },
  background = layout_surface(colors.blue),
})

-- Light path: layout glyph + stack i/n for the focused space only.
local function updateStackIndicator()
  sbar.exec("yabai -m query --spaces --space 2>/dev/null", function(sp)
    if type(sp) ~= "table" then
      return
    end
    local layout = sp.type or "bsp"
    local display = sp.display
    if layout ~= "stack" then
      set_layout_item(layout, "", display)
      return
    end
    sbar.exec("yabai -m query --windows --space 2>/dev/null", function(windows)
      if type(windows) ~= "table" then
        set_layout_item(layout, "", display)
        return
      end
      set_layout_item(layout, format_stack_label(windows), display)
    end)
  end)
end

local function refresh_theme()
  last_layout_key = nil
  updateStackIndicator()
  for idx, _ in pairs(spaces) do
    local st = ensureSpaceState(idx)
    st.last_visual = nil
    st.last_icon_line = nil
    updateSpaceVisual(idx, { force = true })
    renderSpaceApps(idx, false)
  end
end

local function updateLayout()
  if layout_in_flight then
    layout_queued = true
    return
  end
  layout_in_flight = true

  sbar.exec("yabai -m query --spaces 2>/dev/null", function(spaces_data)
    layout_in_flight = false
    if type(spaces_data) ~= "table" then
      if layout_queued then
        layout_queued = false
        updateLayout()
      end
      return
    end

    local present = {}
    for _, yabai_space in ipairs(spaces_data) do
      local index = tonumber(yabai_space.index)
      local display = tonumber(yabai_space.display)
      if index and spaces[index] then
        present[index] = true
        local state = ensureSpaceState(index)
        local sel = yabai_space["has-focus"] == true
        local vis = yabai_space["is-visible"] == true
        if state.display ~= display or state.selected ~= sel or state.visible ~= vis then
          state.last_visual = nil
          state.last_icon_line = nil
        end
        state.display = display or state.display
        state.selected = sel
        state.visible = vis
        spaces[index]:set { display = state.display, drawing = true }
        updateSpaceVisual(index)
        renderSpaceApps(index, false)
      end
    end
    for idx, _ in pairs(spaces) do
      if not present[idx] then
        local st = ensureSpaceState(idx)
        st.selected = false
        st.visible = false
        st.app_names = {}
        st.window_count = 0
        st.last_icon_line = nil
        st.last_visual = nil
        spaces[idx]:set { drawing = false, label = { string = " —" } }
      end
    end

    local focused_space
    for _, yabai_space in ipairs(spaces_data) do
      if yabai_space["has-focus"] then
        focused_space = yabai_space
        break
      end
    end

    if focused_space then
      local layout = focused_space.type or "bsp"
      local display = focused_space.display
      if layout == "stack" then
        sbar.exec("yabai -m query --windows --space 2>/dev/null", function(windows)
          if type(windows) ~= "table" then
            set_layout_item(layout, "", display)
            return
          end
          set_layout_item(layout, format_stack_label(windows), display)
        end)
      else
        set_layout_item(layout, "", display)
      end
    end

    scheduleSpaceWindowRefresh(0)

    if layout_queued then
      layout_queued = false
      updateLayout()
    end
  end)
end

local space_window_observer = sbar.add("item", "widgets.space_window_observer", {
  drawing = false,
  updates = true,
})

-- Window create/move can lag behind yabai; one short retry is enough.
space_window_observer:subscribe("window_created", function()
  scheduleSpaceWindowRefresh(1, 0.12)
end)

space_window_observer:subscribe("window_moved", function()
  scheduleSpaceWindowRefresh(1, 0.15)
end)

space_window_observer:subscribe({
  "space_windows_refresh",
  "window_destroyed",
  "window_minimized",
  "window_deminimized",
  "front_app_switched",
}, function()
  scheduleSpaceWindowRefresh(1, 0.1)
end)

-- Focus changes only need the stack counter + selection colors, not a full windows scan.
space_window_observer:subscribe("window_focus", function()
  updateStackIndicator()
end)

space_window_observer:subscribe("theme_colors_updated", refresh_theme)

space_layout:subscribe("layout_change", updateLayout)
space_layout:subscribe("space_windows_refresh", updateLayout)
space_layout:subscribe("display_change", updateLayout)
space_layout:subscribe("space_created", updateLayout)
space_layout:subscribe("space_destroyed", updateLayout)
space_layout:subscribe("window_moved", updateLayout)
space_layout:subscribe("window_focus", function()
  updateStackIndicator()
end)

updateLayout()
scheduleSpaceWindowRefresh(1)

return spaces
