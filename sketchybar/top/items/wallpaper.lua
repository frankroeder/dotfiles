local colors = require "colors"
local settings = require "settings"

-- Configuration
local PAGE_SIZE = 6
local POPUP_WIDTH = 220
local ITEM_HEIGHT = 120
local THUMB_WIDTH = 200
local THUMB_HEIGHT = 100 -- Target max height for image

local current_page = 1
local all_wallpapers = {}
local is_initialized = false

-- Main Item
local wallpaper = sbar.add("item", "widgets.wallpaper", {
  position = "left",
  icon = {
    string = "􀵪 ",
    font = {
      style = settings.font.style_map["Regular"],
      size = 20.0,
    },
    color = colors.white,
    drawing = true,
    padding_right = 8,
  },
  label = { drawing = false },
  background = {
    color = colors.with_alpha(colors.purple, 0.4),
    border_width = 0,
  },
  popup = {
    align = "left",
    background = {
      border_width = 1,
      border_color = colors.grey,
      color = colors.bg1,
    },
  },
})

-- Wallpaper Setter
local function set_wallpaper(path)
  local cmd = string.format(
    [[osascript -e 'tell application "System Events" to set picture of every desktop to (POSIX file "%s")']],
    path
  )
  os.execute(cmd)
end

-- Pool of items with their current wallpaper paths
local items = {}
local item_paths = {}

-- Create fixed pool of items
for i = 1, PAGE_SIZE do
  local item = sbar.add("item", "wallpaper.item." .. i, {
    position = "popup." .. wallpaper.name,
    drawing = false,
    background = {
      color = colors.transparent,
      image = {
        drawing = true,
        scale = 0.1,
      },
      height = ITEM_HEIGHT,
      corner_radius = 8,
      border_width = 0,
      border_color = colors.white,
    },
    label = {
      drawing = true,
      color = colors.white,
      align = "center",
      padding_left = 10,
      padding_right = 10,
      y_offset = -40,
      font = { size = 9.0 },
      background = {
        color = colors.with_alpha(colors.black, 0.6),
        height = 20,
        corner_radius = 4,
      },
    },
    width = POPUP_WIDTH,
    align = "center",
  })

  item:subscribe("mouse.entered", function()
    item:set {
      background = { border_width = 2 },
    }
  end)

  item:subscribe("mouse.exited", function()
    item:set {
      background = { border_width = 0 },
    }
  end)

  item:subscribe("mouse.clicked", function()
    if item_paths[i] then
      set_wallpaper(item_paths[i])
      wallpaper:set { popup = { drawing = false } }
    end
  end)

  items[i] = item
end

-- Navigation Items
local nav_prev = sbar.add("item", "wallpaper.nav.prev", {
  position = "popup." .. wallpaper.name,
  drawing = false,
  icon = { string = "􀆉", color = colors.white },
  label = { string = "Prev", color = colors.white },
  width = POPUP_WIDTH / 2,
  align = "center",
})

local nav_next = sbar.add("item", "wallpaper.nav.next", {
  position = "popup." .. wallpaper.name,
  drawing = false,
  icon = { string = "􀆊", color = colors.white },
  label = { string = "Next", color = colors.white },
  width = POPUP_WIDTH / 2,
  align = "center",
})

local function set_item_with_dimensions(item, wallpaper_entry)
  local img_w = wallpaper_entry.width
  local img_h = wallpaper_entry.height
  local scale_w = THUMB_WIDTH / img_w
  local scale_h = THUMB_HEIGHT / img_h
  local scale = math.min(scale_w, scale_h)

  item:set {
    drawing = true,
    label = { string = wallpaper_entry.file },
    background = {
      image = {
        string = wallpaper_entry.path,
        scale = scale,
      },
    },
  }
end

local function update_page()
  local start_idx = (current_page - 1) * PAGE_SIZE + 1

  for i = 1, PAGE_SIZE do
    local idx = start_idx + i - 1
    local item = items[i]

    if idx <= #all_wallpapers then
      local wallpaper_entry = all_wallpapers[idx]
      local full_path = wallpaper_entry.path
      item_paths[i] = full_path

      -- Lazy load dimensions async if not cached
      if not wallpaper_entry.width or not wallpaper_entry.height then
        -- Conservative scale for placeholder (works for both landscape/portrait)
        local safe_scale = THUMB_HEIGHT / 2560
        item:set {
          drawing = true,
          label = { string = wallpaper_entry.file },
          background = {
            image = { string = full_path, scale = safe_scale },
            color = colors.with_alpha(colors.grey, 0.1),
          },
        }

        local sips_cmd = [[sips -g pixelWidth -g pixelHeight "]]
          .. full_path
          .. [[" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}']]
        sbar.exec(sips_cmd, function(result)
          local w, h = result:match "(%d+)%s+(%d+)"
          wallpaper_entry.width = tonumber(w) or 2000
          wallpaper_entry.height = tonumber(h) or 1125
          set_item_with_dimensions(item, wallpaper_entry)
        end)
      else
        set_item_with_dimensions(item, wallpaper_entry)
      end
    else
      item_paths[i] = nil
      item:set { drawing = false }
    end
  end

  -- Update Navigation
  local has_prev = current_page > 1
  local has_next = (current_page * PAGE_SIZE) < #all_wallpapers

  nav_prev:set { drawing = has_prev }
  nav_next:set { drawing = has_next }
end

nav_prev:subscribe("mouse.clicked", function()
  if current_page > 1 then
    current_page = current_page - 1
    update_page()
  end
end)

nav_next:subscribe("mouse.clicked", function()
  if (current_page * PAGE_SIZE) < #all_wallpapers then
    current_page = current_page + 1
    update_page()
  end
end)

local function scan_wallpapers()
  if is_initialized then
    return
  end

  -- First get the file list
  local cmd = 'ls "' .. settings.wallpaper.path .. '"'
  local handle = io.popen(cmd)
  local result = handle:read "*a"
  handle:close()

  if not result then
    return
  end

  local files = {}
  for file in result:gmatch "[^\r\n]+" do
    if
      not file:match "^%."
      and (
        file:match "%.jpg$"
        or file:match "%.png$"
        or file:match "%.jpeg$"
        or file:match "%.webp$"
      )
    then
      table.insert(files, file)
    end
  end

  table.sort(files)

  -- Initialize table (dimensions loaded lazily)
  all_wallpapers = {}
  for _, file in ipairs(files) do
    local full_path = settings.wallpaper.path .. "/" .. file

    table.insert(all_wallpapers, {
      file = file,
      path = full_path,
    })
  end

  is_initialized = true
  update_page()
end

wallpaper:subscribe("mouse.clicked", function(env)
  scan_wallpapers()
  wallpaper:set { popup = { drawing = "toggle" } }
end)

wallpaper:subscribe("mouse.exited.global", function(env)
  wallpaper:set { popup = { drawing = false } }
end)

return wallpaper