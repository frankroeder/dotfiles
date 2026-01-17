local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"

local interface = utils.get_wifi_interface()
local popup_width = 250

local wifi = sbar.add("item", "widgets.wifi", {
  position = "right",
  icon = {
    font = {
      style = "Regular",
      size = 16.0,
    },
    string = icons.wifi.disconnected,
    color = colors.red,
  },
  label = { drawing = false },
  background = { drawing = false },
})

local ssid = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    font = {
      style = settings.font.style_map["Bold"],
    },
    string = icons.wifi.router,
  },
  width = popup_width,
  align = "center",
  label = {
    font = {
      size = 15,
      style = settings.font.style_map["Bold"],
    },
    max_chars = 18,
    string = "????????????",
  },
  background = {
    height = 2,
    color = colors.grey,
    y_offset = -15,
  },
})

local hostname = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    align = "left",
    string = "Hostname:",
    width = popup_width / 2,
  },
  label = {
    max_chars = 20,
    string = "????????????",
    width = popup_width / 2,
    align = "right",
  },
})

local ip = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    align = "left",
    string = "IP:",
    width = popup_width / 2,
  },
  label = {
    string = "???.???.???.???",
    width = popup_width / 2,
    align = "right",
  },
})

local mask = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    align = "left",
    string = "Subnet mask:",
    width = popup_width / 2,
  },
  label = {
    string = "???.???.???.???",
    width = popup_width / 2,
    align = "right",
  },
})

local router = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    align = "left",
    string = "Router:",
    width = popup_width / 2,
  },
  label = {
    string = "???.???.???.???",
    width = popup_width / 2,
    align = "right",
  },
})

wifi:subscribe({ "wifi_change", "system_woke" }, function(env)
  sbar.exec("ipconfig getifaddr " .. interface, function(ip_addr)
    local connected = not (ip_addr == "")
    wifi:set {
      icon = {
        string = connected and icons.wifi.connected or icons.wifi.disconnected,
        color = connected and colors.white or colors.red,
      },
    }
  end)
end)

local function hide_details()
  wifi:set { popup = { drawing = false } }
end

local function toggle_details()
  local should_draw = wifi:query().popup.drawing == "off"
  if should_draw then
    wifi:set { popup = { drawing = true } }
    sbar.exec("networksetup -getcomputername", function(result)
      hostname:set { label = result }
    end)
    sbar.exec("ipconfig getifaddr " .. interface, function(result)
      ip:set { label = result }
    end)
    sbar.exec(
      [[
          en="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')";
          ipconfig getsummary "$en" | grep -Fxq "  Active : FALSE" || \
              networksetup -listpreferredwirelessnetworks "$en" | sed -n '2s/^\t//p'
      ]],
      function(result)
        ssid:set { label = result }
      end
    )
    sbar.exec(
      "networksetup -getinfo Wi-Fi | awk -F 'Subnet mask: ' '/^Subnet mask: / {print $2}'",
      function(result)
        mask:set { label = result }
      end
    )
    sbar.exec(
      "networksetup -getinfo Wi-Fi | awk -F 'Router: ' '/^Router: / {print $2}'",
      function(result)
        router:set { label = result }
      end
    )
  else
    hide_details()
  end
end

wifi:subscribe("mouse.clicked", toggle_details)
wifi:subscribe("mouse.exited.global", hide_details)

local function copy_label_to_clipboard(env)
  local label = sbar.query(env.NAME).label.value
  sbar.exec('echo "' .. label .. '" | pbcopy')
  sbar.set(env.NAME, { label = { string = icons.clipboard, align = "center" } })
  sbar.delay(1, function()
    sbar.set(env.NAME, { label = { string = label, align = "right" } })
  end)
end

ssid:subscribe("mouse.clicked", copy_label_to_clipboard)
hostname:subscribe("mouse.clicked", copy_label_to_clipboard)
ip:subscribe("mouse.clicked", copy_label_to_clipboard)
mask:subscribe("mouse.clicked", copy_label_to_clipboard)
router:subscribe("mouse.clicked", copy_label_to_clipboard)
