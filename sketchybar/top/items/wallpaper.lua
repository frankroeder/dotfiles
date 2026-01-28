local colors = require "colors"
local settings = require "settings"

-- Configuration
local PAGE_SIZE = 6
local POPUP_WIDTH = 220
local ITEM_HEIGHT = 115
local THUMB_WIDTH = 200
local THUMB_HEIGHT = 100
local PREFETCH_PAGES = 2

local current_page = 1
local all_wallpapers = {}
local is_initialized = false
local is_scanning = false
local dimensions_cache = {}

-- Main Item
local wallpaper = sbar.add("item", "widgets.wallpaper", {
  position = "right",
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
      border_width = 2,
      border_color = colors.with_alpha(colors.purple, 0.5),
      color = colors.bg1,
      corner_radius = 10,
      shadow = { drawing = true },
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
      corner_radius = 10,
      border_width = 0,
    },
    label = {
      drawing = false,
    },
    width = POPUP_WIDTH,
    align = "center",
  })

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
  icon = { string = "􀆉", color = colors.white, font = { size = 14.0 } },
  label = { string = "Prev", color = colors.white, font = { size = 12.0 } },
  width = POPUP_WIDTH / 2,
  align = "center",
  background = { color = colors.transparent, corner_radius = 6, height = 28 },
})

local nav_next = sbar.add("item", "wallpaper.nav.next", {
  position = "popup." .. wallpaper.name,
  drawing = false,
  icon = { string = "􀆊", color = colors.white, font = { size = 14.0 } },
  label = { string = "Next", color = colors.white, font = { size = 12.0 } },
  width = POPUP_WIDTH / 2,
  align = "center",
  background = { color = colors.transparent, corner_radius = 6, height = 28 },
})


local page_indicator = sbar.add("item", "wallpaper.page_indicator", {
  position = "popup." .. wallpaper.name,
  drawing = false,
  icon = { drawing = false },
  label = {
    string = "",
    color = colors.grey,
    font = { size = 10.0 },
  },
  width = POPUP_WIDTH,
  align = "center",
  background = { color = colors.transparent },
})

local function calculate_scale(width, height)
  local scale_w = THUMB_WIDTH / width
  local scale_h = THUMB_HEIGHT / height
  return math.min(scale_w, scale_h)
end

local function set_item_with_dimensions(item, wallpaper_entry)
  local scale = calculate_scale(wallpaper_entry.width, wallpaper_entry.height)
  item:set {
    drawing = true,
    background = {
      image = { string = wallpaper_entry.path, scale = scale },
    },
  }
end

local function load_dimensions_async(wallpaper_entry, callback)
  if dimensions_cache[wallpaper_entry.path] then
    wallpaper_entry.width = dimensions_cache[wallpaper_entry.path].width
    wallpaper_entry.height = dimensions_cache[wallpaper_entry.path].height
    if callback then callback(wallpaper_entry) end
    return
  end

  local sips_cmd = [[sips -g pixelWidth -g pixelHeight "]] .. wallpaper_entry.path .. [[" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}']]
  sbar.exec(sips_cmd, function(result)
    local w, h = result:match "(%d+)%s+(%d+)"
    wallpaper_entry.width = tonumber(w) or 2000
    wallpaper_entry.height = tonumber(h) or 1125
    dimensions_cache[wallpaper_entry.path] = { width = wallpaper_entry.width, height = wallpaper_entry.height }
    if callback then callback(wallpaper_entry) end
  end)
end

local function prefetch_pages()
  local start_page = math.max(1, current_page)
  local end_page = math.min(math.ceil(#all_wallpapers / PAGE_SIZE), current_page + PREFETCH_PAGES)

  for page = start_page, end_page do
    local start_idx = (page - 1) * PAGE_SIZE + 1
    for i = 1, PAGE_SIZE do
      local idx = start_idx + i - 1
      if idx <= #all_wallpapers then
        local entry = all_wallpapers[idx]
        if not entry.width and not dimensions_cache[entry.path] then
          load_dimensions_async(entry)
        end
      end
    end
  end
end

local function update_page()
  local start_idx = (current_page - 1) * PAGE_SIZE + 1

  for i = 1, PAGE_SIZE do
    local idx = start_idx + i - 1
    local item = items[i]

    if idx <= #all_wallpapers then
      local wallpaper_entry = all_wallpapers[idx]
      item_paths[i] = wallpaper_entry.path

      if wallpaper_entry.width and wallpaper_entry.height then
        set_item_with_dimensions(item, wallpaper_entry)
        item:set { background = { color = colors.transparent } }
      else
        local safe_scale = 0.04
        item:set {
          drawing = true,
          background = {
            image = { string = wallpaper_entry.path, scale = safe_scale },
            color = colors.with_alpha(colors.grey, 0.05),
          },
        }
        load_dimensions_async(wallpaper_entry, function(entry)
          set_item_with_dimensions(item, entry)
          item:set { background = { color = colors.transparent } }
        end)
      end
    else
      item_paths[i] = nil
      item:set { drawing = false }
    end
  end

  local has_prev = current_page > 1
  local has_next = (current_page * PAGE_SIZE) < #all_wallpapers
  local total_pages = math.ceil(#all_wallpapers / PAGE_SIZE)

  nav_prev:set { drawing = has_prev }
  nav_next:set { drawing = has_next }

  if total_pages > 1 then
    page_indicator:set {
      drawing = true,
      label = { string = "Page " .. current_page .. " / " .. total_pages },
    }
  else
    page_indicator:set { drawing = false }
  end

  prefetch_pages()
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
  if is_initialized or is_scanning then
    return
  end

  is_scanning = true
  local cmd = 'ls "' .. settings.wallpaper.path .. '"'

  sbar.exec(cmd, function(result)
    if not result then
      is_scanning = false
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

    all_wallpapers = {}
    for _, file in ipairs(files) do
      table.insert(all_wallpapers, {
        file = file,
        path = settings.wallpaper.path .. "/" .. file,
      })
    end

    is_initialized = true
    is_scanning = false
    update_page()
  end)
end

wallpaper:subscribe("mouse.clicked", function(env)
  scan_wallpapers()
  wallpaper:set { popup = { drawing = "toggle" } }
end)

wallpaper:subscribe("mouse.exited.global", function(env)
  wallpaper:set { popup = { drawing = false } }
end)

return wallpaper