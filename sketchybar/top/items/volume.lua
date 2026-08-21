local colors = require "colors"
local settings = require "settings"
local logic = require "logic"
local utils = require "utils"

local last_level = 0
local last_muted = false
local scroll_step = settings.volume.scroll_step or 10

local volume = sbar.add("item", "widgets.volume", {
  position = "right",
  background = { drawing = false },
  icon = {
    string = logic.volume_icon(100),
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    color = colors.green,
    padding_left = 8,
    padding_right = 4,
  },
  label = {
    string = "--%",
    font = {
      family = settings.font.family,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    color = colors.text,
    padding_right = 0,
  },
  updates = true,
})

local function apply(level, muted)
  last_level = level or 0
  last_muted = muted and true or false
  volume:set {
    icon = {
      string = logic.volume_icon(last_level, last_muted),
      color = colors.green,
    },
    label = {
      string = last_muted and "00%" or logic.volume_label(last_level),
      color = colors.text,
    },
  }
end

local function refresh_volume()
  sbar.exec(
    [[osascript -e 'output volume of (get volume settings)' -e 'output muted of (get volume settings)']],
    function(out)
      local lines = {}
      for line in tostring(out or ""):gmatch "[^\r\n]+" do
        lines[#lines + 1] = line
      end
      apply(tonumber(lines[1]) or last_level, tostring(lines[2] or ""):lower():match "true" ~= nil)
    end
  )
end

volume:subscribe("volume_change", function(env)
  local level = tonumber(env.INFO)
  if level then
    sbar.exec([[osascript -e 'output muted of (get volume settings)']], function(muted_out)
      apply(level, tostring(muted_out or ""):lower():match "true" ~= nil)
    end)
  else
    refresh_volume()
  end
end)

volume:subscribe("deferred_wake", refresh_volume)

volume:subscribe("mouse.scrolled", function(env)
  local delta = utils.scroll_delta(env)
  if delta == 0 then
    return
  end
  local next = last_level + (delta > 0 and scroll_step or -scroll_step)
  if next < 0 then
    next = 0
  elseif next > 100 then
    next = 100
  end
  sbar.exec("osascript -e 'set volume output volume " .. next .. "' -e 'set volume output muted false'", refresh_volume)
end)

volume:subscribe("theme_colors_updated", function()
  apply(last_level, last_muted)
end)

refresh_volume()
