local M = {
  bin = "/opt/homebrew/bin/sketchybar-island",
}

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function M.trigger(name, params)
  local cmd = { M.bin, "--trigger", name }
  if params then
    for key, value in pairs(params) do
      table.insert(cmd, key .. "=" .. shell_quote(value))
    end
  end
  sbar.exec(table.concat(cmd, " ") .. " 2>/dev/null")
end

return M