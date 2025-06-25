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

return {
  paddings = 2,
  group_paddings = 5,
  animation_duration = 15,
  -- icons = "NerdFont",
  icons = "sf-symbols",

  font = {
    text = "Hack Nerd Font",
    numbers = "Hack Nerd Font Mono",

    style_map = {
      ["Regular"] = "Regular",
      ["Semibold"] = "Medium",
      ["Bold"] = "SemiBold",
      ["Heavy"] = "Bold",
      ["Black"] = "ExtraBold",
    },
  },
  print_table = print_table,
}
