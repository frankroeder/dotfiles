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
        scale = 0.8,
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
    color = colors.bg1,
    border_color = colors.purple,
    border_width = 0,
  },
  click_script = "open -a 'Mission Control'",
  updates = true,
})

-- State to track if the built-in display is the primary (Main) display
local builtin_is_main = true

local function update_position()
  sbar.exec("yabai -m query --displays --display", function(display_json)
    if not display_json then
      return
    end

    -- Check if the current display is at (0,0) which indicates it is the "Main" display in arrangement
    -- Note: Yabai returns frame as a JSON object, but regex is faster for simple check
    local x = tonumber(display_json:match '"x":%s*([-%d%.]+)')
    local y = tonumber(display_json:match '"y":%s*([-%d%.]+)')

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
  end)
end

local function check_displays()
  -- This runs asynchronously and might take a second, but only runs on display changes
  sbar.exec("system_profiler SPDisplaysDataType", function(info)
    -- Find the "Built-in" display block and check if it has "Main Display: Yes"
    -- We assume "Built-in" appears in the name line.
    -- We extract the text from "Built-in" until the next "Display:" or end of string.

    local builtin_block_start = info:find "Built%-in"

    if builtin_block_start then
      -- Look for "Main Display: Yes" roughly after the Built-in string
      -- We need to be careful not to match "Main Display: Yes" of another display.
      -- Usually indentation helps, or we just look ahead a reasonable amount (e.g. 500 chars)
      -- or split by display entries.

      -- Robust way: split by "Display Type" or just indentation of header.
      -- Simple heuristic: The "Main Display: Yes" line usually appears shortly after the name.
      -- Let's check if "Main Display: Yes" appears BEFORE the NEXT "Display:" or "Resolution:" block of a different display.

      -- Actually, let's just grab the substring from "Built-in"
      local tail = info:sub(builtin_block_start)
      -- Find next display start (headers usually have no indentation or minimal)
      -- But system_profiler format varies.

      -- Let's assume if "Main Display: Yes" is found within the next 20 lines of "Built-in", it's the main one.
      -- Or easier: check if "Built-in" AND "Main Display: Yes" exist.
      -- If "Main Display: Yes" exists, SOME display is main.
      -- If "Built-in" is NOT main, then "Main Display: Yes" would be under another display.

      -- Let's try to match:  Built-in ... (any chars) ... Main Display: Yes
      -- But we must ensure no other Header comes in between.
      -- Headers in SPDisplaysDataType are usually formatted like "      Color LCD:" (6 spaces)
      -- Properties are "          Resolution:" (10 spaces)

      -- So we check if "Main Display: Yes" appears before the next line with 6 spaces indentation?

      -- Let's try a simpler approach:
      -- Does the `tail` string contain "Main Display: Yes" before it contains another line starting with exactly 6 spaces?

      local next_header = tail:find "\n%s%s%s%s%s%s[^%s]" -- Find \n followed by 6 spaces and non-space
      -- The Built-in line itself starts with 6 spaces, so we search after that.

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
