local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local app_icons = require "helpers.app_icons"

sbar.add("event", "layout_change")
sbar.add("event", "property_change")
sbar.add("event", "window_focused")
sbar.add("event", "window_created")
sbar.add("event", "window_destroyed")

local spaces = {}

local static_names = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

for i, space_name in ipairs(static_names) do
  local space = sbar.add("space", "space." .. i, {
    space = i,
    icon = {
      font = { family = settings.font.numbers },
      string = space_name,
      padding_left = 6,
      padding_right = 6,
      color = colors.white,
      highlight_color = colors.blue,
    },
    label = {
      padding_right = 6,
      color = colors.grey,
      highlight_color = colors.white,
      font = "sketchybar-app-font:Regular:16.0",
      y_offset = 1,
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      color = colors.bg1,
      border_width = 1,
      height = 24,
      border_color = colors.black,
    },
    click_script = "yabai -m space --focus " .. i,
  })

  spaces[i] = space

  -- Single item bracket for space items to achieve double border on highlight
  local space_bracket = sbar.add("bracket", { space.name }, {
    background = {
      color = colors.transparent,
      border_color = colors.bg2,
      height = 28,
      border_width = 2,
    },
  })

  local space_popup = sbar.add("item", {
    position = "popup." .. space.name,
    padding_left = 5,
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
      background = { border_color = selected and colors.black or colors.bg2 },
    }
    space_bracket:set {
      background = { border_color = selected and colors.grey or colors.bg2 },
    }
  end)

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "other" then
      space_popup:set { background = { image = "space." .. env.SID } }
      space:set { popup = { drawing = "toggle" } }
    else
      local op = (env.BUTTON == "right") and "--destroy" or "--focus"
      sbar.exec("yabai -m space " .. op .. " " .. env.SID)
    end
  end)

  space:subscribe("mouse.exited", function(_)
    space:set { popup = { drawing = false } }
  end)
end

local space_layout = sbar.add("item", "yabai_layout", {
  icon = {
    font = { family = settings.font.numbers },
    string = icons.yabai.bsp,
  },
  label = {
    string = "",
  },
})

local function updateLayout()
  sbar.exec(
    [[yabai -m query --spaces --display | jq -r 'map(select(."has-focus" == true))[-1] | "\(.type) \(.display)"']],
    function(out)
      local layout, display = out:match "(%S+)%s+(%S+)"
      local stack_info = ""

      if layout == "stack" then
        local file =
          io.popen [[yabai -m query --windows --space | jq -r 'map(select(."is-visible" == true)) | length']]
        if file == nil then
          return
        end
        local stack_total = file:read("*a"):match "(%S+)"
        file:close()

        local file =
          io.popen [[yabai -m query --windows --space | jq -r 'map(select(."has-focus" == true))[-1]."stack-index"']]
        if file == nil then
          return
        end
        local stack_position = file:read("*a"):match "(%S+)"
        file:close()
        if stack_position == "null" then
          stack_info = "[NA]"
        else
          stack_info = "[" .. tostring(stack_position) .. "/" .. tostring(stack_total) .. "]"
        end
      else
        stack_info = ""
      end
      space_layout:set {
        icon = {
          string = icons.yabai[layout],
        },
        label = {
          string = stack_info,
        },
        display = tonumber(display),
      }
    end
  )
end

local window_properties = sbar.add("item", {
  label = {
    font = { family = settings.font.text, size = 12 },
    color = colors.white,
    padding_left = 4,
    padding_right = 4,
  },
  background = {
    color = colors.bg2,
    border_width = 1,
    height = 24,
    -- border_color = colors.black,
    border_color = colors.bg2,
    -- color = colors.red,
    color = colors.bg1,
  },
  drawing = false,
})

local function getWindowProperties()
  sbar.exec(
    [[yabai -m query --windows --space | jq -r 'map(select(."has-focus" == true))[-1] | "\(."is-sticky") \(."is-topmost") \(."is-floating") \(."has-parent-zoom")"']],
    function(out)
      local _is_sticky, _is_topmost, _is_floating, _has_parent_zoom =
        out:match "(%S+)%s+(%S+)%s+(%S+)%s+(%S+)"
      local is_sticky = _is_sticky == "true" or false
      local is_topmost = _is_topmost ~= "null" or false
      local is_floating = _is_floating == "true" or false
      local has_parent_zoom = _has_parent_zoom == "true" or false
      local label = ""
      print("PROP", out, is_sticky, is_topmost, is_floating, has_parent_zoom)
      if is_sticky then
        label = label .. "S"
      end
      if is_topmost then
        label = label .. "T"
      end
      if is_floating then
        label = label .. "W"
      end
      if has_parent_zoom then
        label = label .. "Z"
      end
      window_properties:set {
        label = { string = label },
        -- drawing = label ~= "",
        drawing = label ~= "",
      }
    end
  )
end

local space_window_observer = sbar.add("item", {
  drawing = false,
  updates = true,
})

local updateSpace = function(space_idx)
  sbar.exec(
    "yabai -m query --windows --space " .. space_idx .. " | jq -r 'map(.app)'",
    function(apps)
      print("APPS SPACE IDX", apps, space_idx)
      settings.print_table(apps)
      if apps == "null" then
        return
      end
      local icon_line = ""
      local no_app = true
      for idx, app in pairs(apps) do
        no_app = false
        local lookup = app_icons[app]
        local icon = ((lookup == nil) and app_icons["Default"] or lookup)
        icon_line = icon_line .. icon
      end
      if no_app then
        icon_line = " —"
      end
      sbar.animate("tanh", settings.animation_duration, function()
        spaces[tonumber(space_idx)]:set { label = icon_line }
      end)
    end
  )
end

-- space_window_observer:subscribe("front_app_switched", "space_change", "window_created", "window_destroyed", function(env)
-- update all spaces
space_window_observer:subscribe("space_change", "window_created", "window_destroyed", function(env)
  sbar.exec("yabai -m query --spaces", function(spaces_info)
    for idx, space_info in ipairs(spaces_info) do
      print("Space " .. idx .. ":", space_info["uuid"])
      updateSpace(idx)
    end
  end)
end)

space_window_observer:subscribe("space_windows_change", function(env)
  print "FRONT APP"
  settings.print_table(env)
  updateSpace(env.INFO.space)
end)

-- space_window_observer:subscribe("display_change", function(env)
--   print("DISPLAY APP")
--   settings.print_table(env)
--   -- updateSpace(env.INFO.space)
-- end)

-- TODO: Not working --
-- space_layout:subscribe("front_app_switched", "window_focus", "layout_change", function()
--   updateLayout()
-- end)

space_layout:subscribe("layout_change", "front_app_switched", "window_focus", updateLayout)
window_properties:subscribe(
  "property_change",
  "front_app_switched",
  "display_change",
  getWindowProperties
)

return spaces
