local colors = require "colors"
local settings = require "settings"

local front_app = sbar.add("item", "top.front_app", {
  display = "active",
  position = "left", -- Default to left
  icon = {
    background = {
      drawing = true,
      image = {
        corner_radius = 5,
        padding_left = 4,
        scale = 1.0,
      },
    },
    font = "sketchybar-app-font:Regular:22.0",
  },
  label = {
    padding_left = 10,
    padding_right = 10,
    font = {
      style = settings.font.style_map["Bold"],
      size = 16.0,
    },
  },
  background = {
    drawing = false
  },
  click_script = "open -a 'Mission Control'",
  updates = true,
})

-- State to track if the built-in display is the primary (Main) display
local builtin_is_main = true

local function update_position()
  sbar.exec("yabai -m query --displays --display", function(display_json)
    local json_str = tostring(display_json)
    if not json_str or json_str == "" or json_str == "nil" then
      return
    end

    -- Check if the current display is at (0,0) which indicates it is the "Main" display in arrangement
    -- Note: Yabai returns frame as a JSON object, but regex is faster for simple check
    local x = tonumber(json_str:match '"x":%s*([-%d%.]+)')
    local y = tonumber(json_str:match '"y":%s*([-%d%.]+)')

    if x and y then
      local is_main_frame = (x == 0 and y == 0)

      -- Logic:
      -- If (Current is Main) == (Built-in is Main) -> Current is Built-in -> LEFT
      -- Else -> Current is External -> CENTER

      local is_builtin = (is_main_frame == builtin_is_main)

      if is_builtin then
        front_app:set { position = "left" }
      else
        front_app:set { position = "center" }
      end
    end
  end)
end

local function check_displays()
  -- This runs asynchronously and might take a second, but only runs on display changes
  sbar.exec("system_profiler SPDisplaysDataType", function(info)
    -- Find the "Built-in" display block and check if it has "Main Display: Yes"
    if not info then return end

    local builtin_block_start = info:find "Built%-in"

    if builtin_block_start then
      -- Look for "Main Display: Yes" roughly after the Built-in string
      local tail = info:sub(builtin_block_start)
      
      local next_header = tail:find "\n%s%s%s%s%s%s[^%s]" -- Find \n followed by 6 spaces and non-space
      local limit = next_header or #tail
      local block = tail:sub(1, limit)

      if block:find "Main Display: Yes" then
        builtin_is_main = true
      else
        builtin_is_main = false
      end
    else
      -- No Built-in display found (e.g. Clamshell mode)
      builtin_is_main = false
    end

    update_position()
  end)
end

front_app:subscribe("front_app_switched", function(env)
  update_position() -- Check position whenever app switches (often implies display focus change)
  sbar.animate("tanh", 20, function()
    front_app:set {
      label = { string = env.INFO },
      icon = { background = { image = { string = "app." .. env.INFO } } },
    }
  end)
end)

front_app:subscribe({ "display_change" }, function()
  check_displays()
end)

front_app:subscribe({ "window_focus" }, function()
  update_position()
end)

check_displays()
