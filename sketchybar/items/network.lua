-- local icons = require("icons")
-- local colors = require("colors")

-- local network_down = sbar.add("item", {
--   name = "network_down",
--   position = "right",
--   icon = {
--     string = icons.download,
--     font = {
--       style = "Bold",
--       size = 10.0,
--     },
--     highlight_color = colors.blue,
--   },
--   label = {
--     string = "",
--     font = {
--       style = "Bold",
--       size = 10.0,
--     },
--   },
--   y_offset = -5,
--   width = 0,
--   update_freq = 2, -- match your old config's frequency
-- })

-- local network_up = sbar.add("item", {
--   name = "network_up", -- match your existing config name
--   position = "right",
--   icon = {
--     string = icons.upload,
--     font = {
--       style = "Bold",
--       size = 10.0,
--     },
--     highlight_color = colors.red,
--   },
--   label = {
--     string = "",
--     font = {
--       style = "Bold",
--       size = 10.0,
--     },
--   },
--   y_offset = 5,
--   width = 0,
--   update_freq = 2,
-- })

-- local function format_speed_kbps(value_kbps)
--   -- value_kbps is an integer (kilobits per second)
--   if value_kbps > 999 then
--     return string.format("%.0f Mbps", value_kbps / 1000)
--   else
--     return string.format("%d kbps", value_kbps)
--   end
-- end

-- local function network_update()
--   -- We replicate: "ifstat -i en0 -b 0.1 1 | tail -n1"
--   local cmd = [[ ifstat -i "en0" -b 0.1 1 | tail -n1 ]]
--   sbar.exec(cmd, function(output)
--     -- If output is something like: "123 456" (two columns)
--     local down_str, up_str = output:match "([^%s]+)%s+([^%s]+)"
--     if not down_str or not up_str then
--       -- If parsing fails, clear labels
--       network_down:set { label = "", icon = { highlight = false } }
--       network_up:set { label = "", icon = { highlight = false } }
--       return
--     end

--     local down_kbps = tonumber(down_str) or 0 -- kilobits per second (if -b was bits/s)
--     local up_kbps = tonumber(up_str) or 0

--     local down_format = format_speed_kbps(down_kbps)
--     local up_format = format_speed_kbps(up_kbps)

--     -- Highlight icon if > 0
--     local down_highlight = (down_kbps > 0)
--     local up_highlight = (up_kbps > 0)

--     network_down:set {
--       label = down_format,
--       icon = {
--         highlight = down_highlight,
--       },
--     }

--     network_up:set {
--       label = up_format,
--       icon = {
--         highlight = up_highlight,
--       },
--     }
--   end)
-- end

-- network_down:subscribe("routine", network_update)
-- network_up:subscribe("routine", network_update)

-- return {
--   network_down,
--   network_up,
-- }

local icons = require "icons"
local colors = require "colors"
local settings = require "settings"

-- Execute the event provider binary which provides the event "network_update"
-- for the network interface "en0", which is fired every 2.0 seconds.
sbar.exec "killall network_load >/dev/null; $CONFIG_DIR/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0"

local network_down = sbar.add("item", { "network_down" }, {
  position = "right",
  padding_right = 0,
  width = 0,
  icon = {
    padding_right = 0,
    string = icons.wifi.download,
    font = {
      style = settings.font.style_map["Bold"],
      size = 10.0,
    },
    highlight_color = colors.blue,
  },
  label = {
    string = "??? Bps",
    font = {
      style = settings.font.style_map["Bold"],
      size = 10.0,
    },
  },
  y_offset = 5,
})

local network_up = sbar.add("item", { "network_up" }, {
  position = "right",
  width = 0,
  padding_right = 0,
  icon = {
    padding_right = 0,
    string = icons.wifi.upload,
    font = {
      style = settings.font.style_map["Bold"],
      size = 10.0,
    },
    highlight_color = colors.red,
  },
  label = {
    string = "??? Bps",
    font = {
      style = settings.font.style_map["Bold"],
      size = 10.0,
    },
  },
  y_offset = -5,
})

network_up:subscribe("network_update", function(env)
  local up_color = (env.upload == "000 Bps") and colors.grey or colors.pink
  local down_color = (env.download == "000 Bps") and colors.grey or colors.blue
  network_up:set {
    icon = { color = up_color },
    label = {
      string = env.upload,
      color = up_color,
    },
  }
  network_down:set {
    icon = { color = down_color },
    label = {
      string = env.download,
      color = down_color,
    },
  }
end)
