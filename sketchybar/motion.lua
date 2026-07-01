local bar_config = require "bar_config"
local settings = require "settings"

local M = {
  curve = "tanh",
  frames = settings.motion,
}

function M.animate_bar(props, frames)
  sbar.animate(M.curve, frames or M.frames.normal, function()
    bar_config.bar(props)
  end)
end

return M