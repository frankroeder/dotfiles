local icons = require "icons"
local colors = require "colors"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"
local network = require "items.network"

sbar.add("event", "network_change", "com.apple.networkConnect")

local col = settings.layout.columns
local interface = utils.get_wifi_interface()
local popup_width = 280
local row_width = popup_width / 2
local popup_row_height = settings.ui.popup_row_height

local wifi = ui.bracket_icon("widgets.wifi", {
  width = col.wifi,
  icon = {
    font = {
      style = settings.font.style_map["Regular"],
      size = 18.0,
    },
    string = icons.wifi.disconnected,
    color = colors.red,
    width = col.wifi_icon,
    align = "center",
    padding_left = 2,
    padding_right = 6,
  },
})

local ssid = ui.popup_header("widgets.wifi.ssid", wifi, {
  icon = icons.wifi.router,
  icon_font = { style = settings.font.style_map["Bold"] },
  width = popup_width,
  label = "????????????",
  label_font = { size = 14, style = settings.font.style_map["Bold"] },
  max_chars = 24,
  background = {
    height = 2,
    color = settings.theme.border,
    y_offset = -15,
  },
})

local function wifi_detail(name, title, label)
  return ui.popup_field(name, wifi, {
    icon = title,
    icon_width = row_width,
    label = label,
    label_width = row_width,
    label_align = "right",
    max_chars = name == "widgets.wifi.hostname" and 26 or nil,
    height = popup_row_height,
  })
end

local hostname = wifi_detail("widgets.wifi.hostname", "Hostname:", "????????????")
local ip = wifi_detail("widgets.wifi.ip", "IP:", "???.???.???.???")
local mask = wifi_detail("widgets.wifi.mask", "Subnet mask:", "???.???.???.???")
local router = wifi_detail("widgets.wifi.router", "Router:", "???.???.???.???")

local function update_wifi()
  interface = utils.get_wifi_interface()
  sbar.exec("ipconfig getifaddr " .. interface, function(ip_addr)
    local connected = not (ip_addr == "")
    if connected then
      wifi:set {
        icon = { string = icons.wifi.connected, color = colors.text },
      }
    else
      local cmd = string.format(
        [[
        for ifc in $(networksetup -listallhardwareports | awk '/Device: en/{print $2}'); do
          [ "$ifc" = "%s" ] && continue
          ipconfig getifaddr "$ifc" >/dev/null 2>&1 && { echo "1"; exit; }
        done; printf ''
      ]],
        interface
      )
      sbar.exec(cmd, function(lan)
        local on_lan = lan and lan:match "%S" ~= nil
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

wifi:subscribe({ "forced", "wifi_change", "network_change", "deferred_wake" }, update_wifi)
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
    sbar.exec(
      string.format(
        [[
      networksetup -listallhardwareports | awk -v dev="%s" '
        /^Hardware Port:/ { port = substr($0, index($0, ": ")+2); getline; if ($2 == dev) { print port; exit } }
      ' | tr -d '\n'
    ]],
        active_if
      ),
      function(result)
        ssid:set { label = result ~= "" and result or active_if }
      end
    )
  end

  sbar.exec(
    string.format(
      [[
    ipconfig getpacket "%s" 2>/dev/null | awk '/subnet_mask/ {print $NF}' | tr -d '\n'
  ]],
      active_if
    ),
    function(result)
      mask:set { label = result }
    end
  )
  sbar.exec(
    string.format(
      [[
    ipconfig getpacket "%s" 2>/dev/null | sed -n 's/.*router[^:]*: *{\([^}]*\)}.*/\1/p' | tr -d '\n'
  ]],
      active_if
    ),
    function(result)
      router:set { label = result }
    end
  )
end

ui.bind_popup_group(wifi, { wifi, network.up, network.down }, { on_open = update_details })

local function copy_label(env)
  utils.clipboard_copy(env.NAME, icons)
end

ssid:subscribe("mouse.clicked", copy_label)
hostname:subscribe("mouse.clicked", copy_label)
ip:subscribe("mouse.clicked", copy_label)
mask:subscribe("mouse.clicked", copy_label)
router:subscribe("mouse.clicked", copy_label)

wifi:subscribe("theme_colors_updated", function()
  ssid:set { background = { color = settings.theme.border } }
  wifi:set {
    background = { drawing = false },
    icon = { color = settings.theme.text_primary },
  }
  update_wifi()
end)
