local settings = require "settings"
local ui = require "ui"

sbar.add("event", "property_change")

local front_app = sbar.add("item", "top.front_app", {
  display = "active",
  position = "left", -- Default to left
  icon = {
    background = {
      drawing = true,
      image = {
        corner_radius = 5,
        padding_left = 4,
        scale = 0.9,
      },
    },
    font = settings.font.app_icon .. ":Regular:22.0",
  },
  label = {
    padding_left = 10,
    padding_right = 10,
    font = {
      style = settings.font.style_map["Bold"],
      size = 16.0,
    },
  },
  background = ui.capsule {
    color = settings.theme.surface,
    border_color = settings.theme.border,
  },
  click_script = "open -a 'Mission Control'",
  updates = true,
})

-- State to track if the built-in display is the primary (Main) display
local builtin_is_main = true
local current_front_app = ""

local function update_position()
  sbar.exec("yabai -m query --displays --display", function(display_json)
    if not display_json then
      return
    end

    local x = tonumber(display_json:match '"x":%s*([-%d%.]+)')
    local y = tonumber(display_json:match '"y":%s*([-%d%.]+)')

    local is_main_frame = (x == 0 and y == 0)
    local is_builtin = (is_main_frame == builtin_is_main)

    if is_builtin then
      front_app:set { position = "left" }
    else
      front_app:set { position = "center" }
    end
  end)
end

local function check_displays()
  sbar.exec("system_profiler SPDisplaysDataType", function(info)
    local builtin_block_start = info:find "Built%-in"

    if builtin_block_start then
      local tail = info:sub(builtin_block_start)
      local next_header = tail:find "\n%s%s%s%s%s%s[^%s]"
      local limit = next_header or #tail
      local block = tail:sub(1, limit)

      if block:find "Main Display: Yes" then
        builtin_is_main = true
      else
        builtin_is_main = false
      end
    else
      builtin_is_main = false
    end

    update_position()
  end)
end

local function updateFrontAppProperties()
  sbar.exec("yabai -m query --windows --window 2>/dev/null", function(window)
    if type(window) ~= "table" then
      front_app:set { label = { string = current_front_app } }
      return
    end

    local app_name = tostring(window.app or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if app_name ~= "" and current_front_app == "" then
      current_front_app = app_name
    end

    local name = current_front_app ~= "" and current_front_app or app_name
    if name == "" then
      name = app_name
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

    local label = name
    if #flags > 0 then
      label = label .. " " .. table.concat(flags, " ")
    end

    front_app:set { label = { string = label } }
  end)
end

front_app:subscribe("front_app_switched", function(env)
  current_front_app = env.INFO or ""
  update_position()
  sbar.animate("tanh", 20, function()
    front_app:set {
      label = { string = current_front_app },
      icon = { background = { image = { string = "app." .. current_front_app } } },
    }
  end)
  updateFrontAppProperties()
end)

front_app:subscribe({ "display_change" }, function()
  check_displays()
end)

front_app:subscribe({ "window_focus" }, function()
  update_position()
  updateFrontAppProperties()
end)

front_app:subscribe("property_change", updateFrontAppProperties)

check_displays()

-- initial properties fetch (in case switched event hasn't populated yet)
sbar.delay(0.2, function()
  sbar.exec("yabai -m query --windows --window 2>/dev/null", function(window)
    if type(window) == "table" and window.app then
      current_front_app = tostring(window.app):gsub("^%s+", ""):gsub("%s+$", "")
      front_app:set {
        icon = { background = { image = { string = "app." .. current_front_app } } },
      }
      updateFrontAppProperties()
    end
  end)
end)
