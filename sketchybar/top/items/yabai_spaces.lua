local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

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
      color = colors.white,
      highlight_color = settings.spaces.highlight_color,
    },
    label = {
      padding_right = 6,
      color = colors.grey,
      highlight_color = colors.white,
      font = "sketchybar-app-font:Regular:16.0",
    },
    padding_right = settings.spaces.padding,
    padding_left = settings.spaces.padding,
    background = {
      color = colors.pill_bg,
      border_width = 1,
      height = 26,
      border_color = colors.bg2,
    },
    -- click_script = "yabai -m space --focus " .. i,
  })

  spaces[i] = space

  -- window count indicator
  local window_count = sbar.add("item", "widgets.space.count." .. i, {
    icon = {
      drawing = false,
    },
    padding_left = -2,
    label = {
      string = "",
      font = { family = settings.font.numbers, size = 9.0 },
      color = colors.red,
      padding_left = 0,
      padding_right = 2,
      y_offset = 5,
    },
    background = {
      drawing = false,
    },
    drawing = false,
  })

  space_window_counts[i] = window_count

  -- Single item bracket for space items to achieve double border on highlight
  local space_bracket = sbar.add("bracket", { "widgets.space." .. i, "widgets.space.count." .. i }, {
    background = {
      color = colors.transparent,
      border_color = colors.transparent,
      height = 28,
      border_width = 2,
    },
  })

  local space_popup = sbar.add("item", {
    position = "popup." .. space.name,
    padding_left = 0,
    padding_right = 0,
    background = {
      drawing = true,
      image = {
        corner_radius = 9,
        scale = 0.2,
      },
    },
  })

  space:subscribe("space_change", function(env)
    local selected = env.SELECTED == "true"
    space:set {
      icon = { highlight = selected },
      label = { highlight = selected },
      background = { border_color = selected and colors.transparent or colors.bg2 },
    }
    space_bracket:set {
      background = { border_color = selected and settings.spaces.highlight_color or colors.transparent },
    }
  end)

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "left" then
      space_popup:set { background = { image = "space." .. env.SID } }
      space:set { popup = { drawing = "toggle" } }
      -- sbar.exec("yabai -m query --windows --space " .. env.SID, function(windows)
      --   local window_list = ""
      --   for _, w in ipairs(windows) do
      --     local app = w.app or ""
      --     local title = w.title or ""
      --     window_list = window_list .. "• " .. app .. " - " .. title .. "\n"
      --   end
      --   space_popup:set { label = { string = window_list } }
      --   space:set { popup = { drawing = "toggle" } }
      -- end)
    else
      local op = (env.BUTTON == "right") and "--destroy" or "--focus"
      sbar.exec("yabai -m space " .. op .. " " .. env.SID)
    end
  end)

  space:subscribe("mouse.exited", function(_)
    space:set { popup = { drawing = false } }
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
  },
  background = {
    color = colors.bg1,
    border_width = 2,
    border_color = colors.magenta,
  },
})

local function updateLayout()
  sbar.exec("yabai -m query --spaces", function(spaces_data)
    if not spaces_data then
      return
    end

    -- Update display for all spaces
    for _, s in ipairs(spaces_data) do
      local idx = s.index
      local disp = tonumber(s.display)
      if spaces[idx] and space_window_counts[idx] then
        spaces[idx]:set { display = disp }
        space_window_counts[idx]:set { display = disp }
      end
    end

    -- Find focused space for layout indicator
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
  label = {
    font = { family = settings.font.text, size = 12 },
    color = colors.white,
    padding_left = 4,
    padding_right = 4,
  },
  background = {
    color = colors.pill_bg,
    border_width = 1,
    height = 24,
    border_color = colors.bg2,
  },
  drawing = false,
})

local function getWindowProperties()
  sbar.exec("yabai -m query --windows --window", function(window)
    if not window then
      window_properties:set { drawing = false }
      return
    end

    local is_sticky = window["is-sticky"]
    local is_grabbed = window["is-grabbed"]
    local is_floating = window["is-floating"]
    local has_parent_zoom = window["has-parent-zoom"]

    local label = ""
    if is_sticky then
      label = label .. "S"
    end
    if is_grabbed then
      label = label .. "G"
    end
    if is_floating then
      label = label .. "W"
    end
    if has_parent_zoom then
      label = label .. "Z"
    end

    window_properties:set {
      label = { string = label },
      drawing = label ~= "",
    }
  end)
end

local space_window_observer = sbar.add("item", "widgets.space_window_observer", {
  drawing = false,
  updates = true,
})

space_window_observer:subscribe("space_windows_change", function(env)
  local icon_line = ""
  local no_app = true
  local window_count = 0

  for app, count in pairs(env.INFO.apps) do
    no_app = false
    window_count = window_count + count
    local lookup = app_icons[app]
    local icon = ((lookup == nil) and app_icons["Default"] or lookup)
    icon_line = icon_line .. icon
  end

  if no_app then
    icon_line = "—"
  end

  sbar.animate("tanh", settings.animation_duration, function()
    spaces[env.INFO.space]:set { label = icon_line }

    -- Dim empty spaces
    if spaces[env.INFO.space] then
      local is_empty = no_app
      spaces[env.INFO.space]:set {
        icon = { color = is_empty and colors.grey or colors.white },
        background = { color = is_empty and colors.bg1 or colors.pill_bg },
      }
    end

    -- Update window count
    if space_window_counts[env.INFO.space] then
      if window_count > 0 then
        space_window_counts[env.INFO.space]:set {
          label = { string = tostring(window_count) },
          drawing = true,
        }
      else
        space_window_counts[env.INFO.space]:set { drawing = false }
      end
    end
  end)
end)

-- space_window_observer:subscribe("display_change", function(env)
-- print("DISPLAY APP")
-- settings.print_table(env)
--   -- updateSpace(env.INFO.space)
-- end)

space_layout:subscribe("layout_change", updateLayout)
space_layout:subscribe("front_app_switched", updateLayout)
space_layout:subscribe("display_change", updateLayout)

window_properties:subscribe("property_change", getWindowProperties)
window_properties:subscribe("space_change", getWindowProperties)
window_properties:subscribe("front_app_switched", getWindowProperties)

updateLayout()
getWindowProperties()

return spaces
