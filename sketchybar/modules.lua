local settings = require "settings"

local M = {}

function M.enabled(name)
  local mod = settings.modules[name]
  return mod == nil or mod.enable ~= false
end

function M.option(name, key, default)
  local mod = settings.modules[name]
  if mod and mod[key] ~= nil then
    return mod[key]
  end
  return default
end

return M