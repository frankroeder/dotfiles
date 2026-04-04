local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local app_icons = require "helpers.app_icons"
local ui = require "ui"

sbar.add("event", "layout_change")
sbar.add("event", "property_change")

local spaces = {}
local space_window_counts = {}

local static_names = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

for i, space_name in ipairs(static_names) do
  local space = sbar.add("space", "widgets.space." .. i, {
    space = i,
    icon = {
      font = { family = settings.font.numbers },
      string = space_name,
      padding_left = 6,
      padding_right = 6,
      color = settings.theme.text_primary,
      highlight_color = settings.theme.accent,
    },
    label = {
      padding_right = 6,
      color = settings.theme.text_muted,
      highlight_color = settings.theme.text_primary,
      font = "sketchybar-app-font:Regular:16.0",
    },
    padding_right = settings.spaces.padding,
    padding_left = settings.spaces.padding,
    background = ui.capsule {
      color = settings.theme.surface_alt,
      border_color = settings.theme.border,
      height = 28,
      corner_radius = 8,
    },
    -- click_script = "yabai -m space --focus " .. i,
  })

  spaces[i] = space

  local window_count = sbar.add("item", "widgets.space.count." .. i, {
    icon = {
      drawing = false,
    },
    padding_left = -2,
    label = {
      string = "",
      font = { family = settings.font.numbers, size = 10.0 },
      color = settings.theme.warn,
      padding_left = 0,
      padding_right = 3,
      y_offset = 5,
    },
    background = {
      drawing = false,
    },
    drawing = false,
  })

  space_window_counts[i] = window_count

  local space_bracket = sbar.add(
    "bracket",
    { "widgets.space." .. i, "widgets.space.count." .. i },
    {
      background = {
        color = colors.transparent,
        border_color = colors.transparent,
        height = 32,
        border_width = 2,
      },
    }
  )

  space:subscribe("space_change", function(env)
    local selected = env.SELECTED == "true"
    space:set {
      icon = { highlight = selected },
      label = {
        highlight = selected,
        color = selected and settings.theme.text_primary or settings.theme.text_muted,
      },
      background = {
        border_color = selected and colors.transparent or settings.theme.border,
        color = selected and settings.theme.surface_active or settings.theme.surface_alt,
      },
    }
    space_bracket:set {
      background = {
        border_color = selected and settings.theme.accent or colors.transparent,
      },
    }
  end)

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
      sbar.exec("yabai -m space --destroy " .. i)
    else
      sbar.exec("yabai -m space --focus " .. i)
    end
  end)
end

local space_layout = sbar.add("item", "widgets.yabai_layout", {
  padding_left = 10,
  icon = {
    font = { family = settings.font.numbers },
    string = icons.yabai.bsp,
  },
  label = {
    string = "",
    padding_right = 8,
    color = settings.theme.text_muted,
  },
  background = ui.capsule {
    color = settings.theme.surface_alt,
    border_color = colors.with_alpha(settings.theme.accent_alt, 0.45),
  },
})

local function updateLayout()
  sbar.exec("yabai -m query --spaces", function(spaces_data)
    if not spaces_data then
      return
    end

    for _, s in ipairs(spaces_data) do
      local idx = s.index
      local disp = tonumber(s.display)
      if spaces[idx] and space_window_counts[idx] then
        spaces[idx]:set { display = disp }
        space_window_counts[idx]:set { display = disp }
      end
    end

    local focused_space
    for _, s in ipairs(spaces_data) do
      if s["has-focus"] then
        focused_space = s
        break
      end
    end

    if not focused_space then
      return
    end

    local layout = focused_space.type
    local display = focused_space.display
    local stack_info = "-"

    if layout == "stack" then
      sbar.exec("yabai -m query --windows --space", function(windows)
        if not windows then
          return
        end
        local visible_count = 0
        local stack_index = nil
        for _, w in ipairs(windows) do
          if w["is-visible"] then
            visible_count = visible_count + 1
          end
          if w["has-focus"] then
            stack_index = w["stack-index"]
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
  end)
end

local window_properties = sbar.add("item", "widgets.yabai_property", {
  updates = true,
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 11,
    },
    color = colors.orange,
    padding_left = 2,
    padding_right = 0,
  },
  background = { drawing = false },
  padding_left = 0,
  drawing = false,
})

local function updateWindowProperties()
  sbar.exec("yabai -m query --windows --window 2>/dev/null", function(window)
    if not window then
      window_properties:set { drawing = false }
      return
    end

    local flags = {}
    if window["is-sticky"] then
      table.insert(flags, "S")
    end
    if window["is-floating"] then
      table.insert(flags, "F")
    end
    if window["has-parent-zoom"] then
      table.insert(flags, "Z")
    end

    local label = table.concat(flags, " ")
    window_properties:set {
      label = { string = label },
      drawing = label ~= "",
    }
  end)
end

window_properties:subscribe("property_change", updateWindowProperties)
window_properties:subscribe("front_app_switched", updateWindowProperties)
window_properties:subscribe("window_focus", updateWindowProperties)

local space_window_observer = sbar.add("item", "widgets.space_window_observer", {
  drawing = false,
  updates = true,
})

space_window_observer:subscribe("space_windows_change", function(env)
  local icon_line = ""
  local no_app = true
  local window_count = 0
  local app_names = {}
  local app_icon_list = {}

  for app, count in pairs(env.INFO.apps or {}) do
    no_app = false
    window_count = window_count + count
    table.insert(app_names, app)
  end

  table.sort(app_names)
  for _, app in ipairs(app_names) do
    local lookup = app_icons[app]
    local icon = ((lookup == nil) and app_icons["Default"] or lookup)
    table.insert(app_icon_list, icon)
  end

  if no_app then
    icon_line = "—"
  else
    icon_line = table.concat(app_icon_list, " ")
  end

  sbar.animate("tanh", settings.animation_duration, function()
    local space_index = tonumber(env.INFO and env.INFO.space)
    if not space_index or not spaces[space_index] then
      return
    end

    spaces[space_index]:set {
      label = { string = icon_line },
      icon = { color = no_app and settings.theme.text_muted or settings.theme.text_primary },
    }

    if space_window_counts[space_index] then
      if window_count > 0 then
        space_window_counts[space_index]:set {
          label = { string = tostring(window_count) },
          drawing = true,
        }
      else
        space_window_counts[space_index]:set { drawing = false }
      end
    end
  end)
end)

space_layout:subscribe("layout_change", updateLayout)
space_layout:subscribe("front_app_switched", updateLayout)
space_layout:subscribe("display_change", updateLayout)

updateLayout()
updateWindowProperties()

return spaces
