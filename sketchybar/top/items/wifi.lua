local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"
local network = require "items.network"

sbar.add("event", "network_change", "com.apple.networkConnect")

local interface = utils.get_wifi_interface()
local popup_width = 280
local row_width = popup_width / 2
local popup_row_height = settings.ui.popup_row_height

local wifi = sbar.add("item", "widgets.wifi", {
  position = "right",
  width = 30,
  padding_left = 0,
  padding_right = 0,
  icon = {
    font = {
      style = settings.font.style_map["Regular"],
      size = 18.0,
    },
    string = icons.wifi.disconnected,
    color = colors.red,
    width = 20,
    align = "center",
    padding_left = 6,
    padding_right = 12,
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
      size = 14,
      style = settings.font.style_map["Bold"],
    },
    max_chars = 24,
    string = "????????????",
    align = "center",
  },
  background = {
    height = 2,
    color = settings.theme.border,
    y_offset = -15,
  },
})

local hostname = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    align = "left",
    string = "Hostname:",
    width = row_width,
  },
  label = {
    max_chars = 26,
    string = "????????????",
    width = row_width,
    align = "right",
  },
  background = ui.popup_row(popup_row_height),
})

local ip = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    align = "left",
    string = "IP:",
    width = row_width,
  },
  label = {
    string = "???.???.???.???",
    width = row_width,
    align = "right",
  },
  background = ui.popup_row(popup_row_height),
})

local mask = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    align = "left",
    string = "Subnet mask:",
    width = row_width,
  },
  label = {
    string = "???.???.???.???",
    width = row_width,
    align = "right",
  },
  background = ui.popup_row(popup_row_height),
})

local router = sbar.add("item", {
  position = "popup." .. wifi.name,
  icon = {
    align = "left",
    string = "Router:",
    width = row_width,
  },
  label = {
    string = "???.???.???.???",
    width = row_width,
    align = "right",
  },
  background = ui.popup_row(popup_row_height),
})

local function update_wifi()
  interface = utils.get_wifi_interface()
  sbar.exec("ipconfig getifaddr " .. interface, function(ip_addr)
    local connected = not (ip_addr == "")
    if connected then
      wifi:set {
        icon = {
          string = icons.wifi.connected,
          color = colors.text,
        },
      }
    else
      local cmd = string.format([[
        for ifc in $(networksetup -listallhardwareports | awk '/Device: en/{print $2}'); do
          [ "$ifc" = "%s" ] && continue
          ipconfig getifaddr "$ifc" >/dev/null 2>&1 && { echo "1"; exit; }
        done; printf ''
      ]], interface)
      sbar.exec(cmd, function(lan)
        local on_lan = lan and lan:match("%S") ~= nil
        wifi:set {
          icon = {
            string = on_lan and icons.wifi.lan or icons.wifi.disconnected,
            color = on_lan and colors.text or colors.red,
          },
        }
      end)
    end
  end)
end

wifi:subscribe({ "forced", "wifi_change", "network_change", "system_woke" }, update_wifi)
update_wifi()

local function update_details()
  local wifi_if = utils.get_wifi_interface()
  local active_if = utils.get_primary_interface()
  local using_wifi = (active_if == wifi_if)
  interface = wifi_if

  ssid:set {
    icon = { string = using_wifi and icons.wifi.router or icons.wifi.lan },
  }

  sbar.exec("networksetup -getcomputername", function(result)
    hostname:set { label = result }
  end)
  sbar.exec("ipconfig getifaddr " .. active_if .. " | tr -d '\n'", function(result)
    ip:set { label = result }
  end)

  if using_wifi then
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
  else
    sbar.exec(string.format([[
      networksetup -listallhardwareports | awk -v dev="%s" '
        /^Hardware Port:/ { port = substr($0, index($0, ": ")+2); getline; if ($2 == dev) { print port; exit } }
      ' | tr -d '\n'
    ]], active_if), function(result)
      ssid:set { label = result ~= "" and result or active_if }
    end)
  end

  -- mask/router via getpacket (works for active wifi or lan)
  sbar.exec(string.format([[
    ipconfig getpacket "%s" 2>/dev/null | awk '/subnet_mask/ {print $NF}' | tr -d '\n'
  ]], active_if), function(result)
    mask:set { label = result }
  end)
  sbar.exec(string.format([[
    ipconfig getpacket "%s" 2>/dev/null | sed -n 's/.*router[^:]*: *{\([^}]*\)}.*/\1/p' | tr -d '\n'
  ]], active_if), function(result)
    router:set { label = result }
  end)
end

local function toggle_details()
  utils.popup_toggle(wifi, update_details)
end

wifi:subscribe("mouse.clicked", toggle_details)
network.up:subscribe("mouse.clicked", toggle_details)
network.down:subscribe("mouse.clicked", toggle_details)

wifi:subscribe("mouse.exited.global", function()
  utils.popup_hide(wifi)
end)

local function copy_label(env)
  utils.clipboard_copy(env.NAME, icons)
end

ssid:subscribe("mouse.clicked", copy_label)
hostname:subscribe("mouse.clicked", copy_label)
ip:subscribe("mouse.clicked", copy_label)
mask:subscribe("mouse.clicked", copy_label)
router:subscribe("mouse.clicked", copy_label)
