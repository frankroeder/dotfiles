local colors = require "colors"
local settings = require "settings"

local wallpaper = sbar.add("item", "widgets.wallpaper", {
  position = "left",
  icon = {
    string = "􀵪",
    font = {
      style = settings.font.style_map["Regular"],
      size = 19.0,
    },
    color = colors.white,
    drawing = true,
  },
  label = { drawing = false },
  background = {
    color = colors.transparent,
  },
  popup = {
    align = "center",
    background = {
      border_width = 1,
      border_color = colors.grey,
      color = colors.bg1,
    },
  },
})

-- Function to set wallpaper
local function set_wallpaper(path)
  local cmd = string.format(
    [[osascript -e 'tell application "System Events" to set picture of every desktop to (POSIX file "%s")']],
    path
  )
  print("Executing wallpaper command: " .. cmd)
  os.execute(cmd)
end

-- Function to load wallpapers into popup
local function load_wallpapers()
  -- List files in the directory
  local cmd = 'ls "' .. settings.wallpaper.path .. '"'
  local handle = io.popen(cmd)
  local result = handle:read "*a"
  handle:close()

  if not result then
    return
  end

  local counter = 0
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
      local full_path = settings.wallpaper.path .. "/" .. file
      local item_name = "wallpaper.item." .. counter

      local item = sbar.add("item", item_name, {
        position = "popup." .. wallpaper.name,
        icon = { drawing = false },
        label = {
          string = file,
          color = colors.white,
          padding_left = 10,
          padding_right = 10,
          align = "left",
        },
        background = {
          color = colors.transparent,
          height = 50,
          corner_radius = 5,
        },
        width = "dynamic",
      })

      -- Click event to set wallpaper
      item:subscribe("mouse.clicked", function()
        set_wallpaper(full_path)
        wallpaper:set { popup = { drawing = false } }
      end)

      -- Hover effects
      item:subscribe("mouse.entered", function()
        item:set {
          label = { color = colors.bg1 },
          background = { color = colors.white },
        }
      end)

      item:subscribe("mouse.exited", function()
        item:set {
          label = { color = colors.white },
          background = { color = colors.transparent },
        }
      end)

      counter = counter + 1
    end
  end
end

wallpaper:subscribe("mouse.clicked", function(env)
  load_wallpapers()
  wallpaper:set { popup = { drawing = "toggle" } }
end)

wallpaper:subscribe("mouse.exited.global", function(env)
  wallpaper:set { popup = { drawing = false } }
end)

return wallpaper
