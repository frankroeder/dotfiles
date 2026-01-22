local print_table = function(t, indent)
  indent = indent or 0
  local queue = { { table = t, level = indent, parent_key = "" } }

  while #queue > 0 do
    local current = table.remove(queue, 1)
    local spaces = string.rep("  ", current.level)

    for k, v in pairs(current.table) do
      local full_key = current.parent_key == "" and tostring(k)
        or current.parent_key .. "." .. tostring(k)
      if type(v) == "table" then
        print(spaces .. full_key .. ":")
        table.insert(queue, { table = v, level = current.level + 1, parent_key = full_key })
      else
        print(spaces .. full_key .. ": " .. tostring(v))
      end
    end
  end
end

local settings = {
  paddings = 4,
  animation_duration = 15,
  bar_height = 40,
  bar_padding = 10,
  bar_margin = 10,
  bar_corner_radius = 12,
  bar_color = require("colors").transparent,
  bar_border_color = require("colors").transparent,
  icons = "sf-symbols",
  wallpaper = {
    path = os.getenv "HOME" .. "/Library/Mobile Documents/com~apple~CloudDocs/wallpapers",
    scale = 1.0,
  },
  font = {
    text = "SF Pro",
    numbers = "SF Pro",
    style_map = {
      ["Regular"] = "Regular",
      ["Semibold"] = "Semibold",
      ["Bold"] = "Bold",
      ["Heavy"] = "Heavy",
      ["Black"] = "Black",
    },
  },
  print_table = print_table,
}

return settings
