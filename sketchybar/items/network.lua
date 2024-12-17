local icons = require "icons"
local colors = require "colors"

local network_down = sbar.add("item", { "network_down" }, {
  position = "right",
  icon = {
    string = icons.wifi.download,
    font = {
      size = 10.0,
    },
    highlight_color = colors.blue,
  },
  label = {
    string = "",
    font = {
      size = 10.0,
    },
    padding_right = 8,
  },
  padding_right = -4,
  y_offset = -5,
  width = 0,
  update_freq = 10,
})

local network_up = sbar.add("item", { "network_up" }, {
  position = "right",
  icon = {
    string = icons.wifi.upload,
    font = {
      size = 10.0,
    },
    highlight_color = colors.red,
  },
  label = {
    string = "",
    font = {
      size = 10.0,
    },
    padding_right = 8,
  },
  y_offset = 5,
  update_freq = 2,
  width = 70,
  padding_right = -4,
  -- background = {
  --   color= colors.lightblack
  -- }
})

local function format_speed_kbps(value_kbps)
  -- value_kbps is an integer (kilobits per second)
  if value_kbps > 999 then
    return string.format("%03.0f Mbps", math.floor(tonumber(value_kbps) / 1000))
  else
    return string.format("%03.0f kbps", math.floor(tonumber(value_kbps)))
  end
end

local function network_update()
  local cmd = [[ ifstat -i "en0" -b 0.1 1 | tail -n1 ]]
  sbar.exec(cmd, function(output)
    -- If output is something like: "123 456" (two columns)
    local down_str, up_str = output:match "([^%s]+)%s+([^%s]+)"
    if not down_str or not up_str then
      -- If parsing fails, clear labels
      network_down:set { label = "", icon = { highlight = false } }
      network_up:set { label = "", icon = { highlight = false } }
      return
    end

    local down_kbps = tonumber(down_str) or 0
    local up_kbps = tonumber(up_str) or 0

    local down_format = format_speed_kbps(down_kbps)
    local up_format = format_speed_kbps(up_kbps)

    local down_highlight = (down_kbps > 0)
    local up_highlight = (up_kbps > 0)

    network_down:set {
      label = down_format,
      icon = {
        highlight = down_highlight,
      },
    }

    network_up:set {
      label = up_format,
      icon = {
        highlight = up_highlight,
      },
    }
  end)
end

network_down:subscribe("routine", network_update)
network_up:subscribe("routine", network_update)
network_update()
