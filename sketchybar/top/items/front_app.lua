local bridge = require "island_bridge"
local display = require "display"
local settings = require "settings"
local ui = require "ui"

sbar.add("event", "property_change")

local use_island = settings.island.appswitch

local front_app = sbar.add("item", "top.front_app", {
  display = use_island and display.external_index or "active",
  position = use_island and "center" or "left",
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
  background = ui.widget_background {
    color = settings.theme.surface,
    border_color = settings.theme.border,
  },
  click_script = "open -a 'Mission Control'",
  drawing = true,
  updates = true,
})

local builtin_is_main = true
local current_front_app = ""
local focus_debounce_token = 0

local function update_position()
  if use_island then
    local ext = display.external_index
    if ext then
      front_app:set {
        display = ext,
        position = "center",
        drawing = true,
        background = ui.widget_background(),
      }
    else
      front_app:set { drawing = false, updates = true, background = { drawing = false } }
    end
    return
  end

  front_app:set { display = "active", background = ui.widget_background() }

  sbar.exec("yabai -m query --displays --display", function(disp)
    if type(disp) ~= "table" or not disp.frame then
      return
    end

    local frame = disp.frame
    local x = tonumber(frame.x)
    local y = tonumber(frame.y)
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
  if use_island then
    update_position()
    return
  end

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
  if use_island and current_front_app ~= "" then
    bridge.trigger("island_appswitch", { app = current_front_app })
  end
  update_position()
  if not use_island or display.external_index then
    sbar.animate("tanh", 20, function()
      front_app:set {
        label = { string = current_front_app },
        icon = { background = { image = { string = "app." .. current_front_app } } },
      }
    end)
  end
  updateFrontAppProperties()
end)

front_app:subscribe({ "display_change" }, function()
  check_displays()
end)

front_app:subscribe({ "window_focus" }, function()
  focus_debounce_token = focus_debounce_token + 1
  local token = focus_debounce_token
  sbar.delay(0.15, function()
    if token ~= focus_debounce_token then
      return
    end
    update_position()
    updateFrontAppProperties()
  end)
end)

front_app:subscribe("property_change", updateFrontAppProperties)

front_app:subscribe("theme_colors_updated", function()
  front_app:set {
    background = ui.widget_background(),
    label = { color = settings.theme.text_primary },
  }
end)

check_displays()

local function populate_initial(name)
  name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return
  end
  current_front_app = name
  front_app:set {
    label = { string = name },
    icon = { background = { image = { string = "app." .. name } } },
  }
  updateFrontAppProperties()
end

sbar.delay(0.2, function()
  sbar.exec("yabai -m query --windows --window 2>/dev/null", function(window)
    if type(window) == "table" and window.app then
      populate_initial(window.app)
    else
      -- yabai not ready: fall back to the frontmost app via AppleScript.
      sbar.exec(
        "osascript -e 'tell application \"System Events\" to name of first application process whose frontmost is true' 2>/dev/null",
        populate_initial
      )
    end
  end)
end)