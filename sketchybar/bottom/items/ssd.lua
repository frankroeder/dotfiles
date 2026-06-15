local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local utils = require "utils"
local ui = require "ui"
local popup_row_height = settings.ui.popup_row_height

local icon_thresholds = {
  { min = 98, icon = icons.disk["98"] },
  { min = 88, icon = icons.disk["88"] },
  { min = 76, icon = icons.disk["76"] },
  { min = 64, icon = icons.disk["64"] },
  { min = 52, icon = icons.disk["52"] },
  { min = 40, icon = icons.disk["40"] },
  { min = 28, icon = icons.disk["28"] },
  { min = 16, icon = icons.disk["16"] },
  { min = 1, icon = icons.disk["1"] },
  { min = 0, icon = icons.disk["0"] },
}

local ssd_volume = sbar.add("item", "widgets.ssd.volume", {
  position = "right",
  icon = {
    font = {
      size = 16.0,
    },
    string = icons.disk["0"],
    padding_left = 6,
    padding_right = 4,
  },
  label = {
    font = {
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    align = "right",
    width = 64,
    padding_left = 4,
    padding_right = 6,
    string = "...%",
  },
  update_freq = 600,
  popup = { align = "right" },
  background = ui.capsule {},
})

local function popup_row(name, icon)
  return sbar.add("item", "widgets.ssd." .. name, {
    position = "popup." .. ssd_volume.name,
    icon = {
      string = icon,
      padding_left = 5,
      padding_right = 5,
    },
    label = {
      string = "...",
      padding_right = 11,
    },
    background = ui.popup_row(popup_row_height),
    drawing = false,
  })
end

local swap_row = popup_row("swap", icons.swap)
local root_row = popup_row("root", icons.disk["76"])
local home_row = popup_row("home", icons.disk["64"])
local physical_rows = {
  popup_row("physical.1", icons.disk["98"]),
  popup_row("physical.2", icons.disk["88"]),
  popup_row("physical.3", icons.disk["88"]),
  popup_row("physical.4", icons.disk["88"]),
}

local gib = 1024 * 1024 * 1024
local mib = 1024 * 1024

local function format_bytes(bytes)
  bytes = tonumber(bytes) or 0
  if bytes < gib then
    return string.format("%.2f MiB", bytes / mib)
  end
  return string.format("%.2f GiB", bytes / gib)
end

local function set_row(row, label)
  row:set { drawing = true, label = label }
end

local function volume_types(types)
  if not types or types == "" then
    return ""
  end
  return " [" .. types .. "]"
end

local function free_space_color(free_percent)
  if free_percent <= 8 then
    return settings.theme.critical
  elseif free_percent <= 15 then
    return colors.orange
  elseif free_percent <= 30 then
    return settings.theme.warn
  end
  return settings.theme.success
end

local function swap_to_bytes(value, unit)
  local factor = ({ K = 1024, M = mib, G = gib, T = gib * 1024 })[unit] or 1
  return (tonumber(value) or 0) * factor
end

local function update_swap_row()
  sbar.exec("sysctl vm.swapusage", function(output)
    local total, total_unit = output:match "total = ([%d%.]+)([KMGT])"
    local used, used_unit = output:match "used = ([%d%.]+)([KMGT])"
    total = swap_to_bytes(total, total_unit)
    used = swap_to_bytes(used, used_unit)
    if total == 0 then
      return
    end

    local encrypted = output:lower():match "encrypted" and "Encrypted" or "Normal"
    set_row(
      swap_row,
      string.format(
        "Swap (%s): %s / %s (%d%%)",
        encrypted,
        format_bytes(used),
        format_bytes(total),
        math.floor(used * 100 / total + 0.5)
      )
    )
  end)
end

local function mount_info(output, mountpoint)
  for line in output:gmatch "[^\n]+" do
    local mounted, opts = line:match "^.- on (.-) %((.-)%)$"
    if mounted == mountpoint then
      local fs = opts:match "^[^,]+"
      local read_only = opts:match "read%-only" and "Read-only" or nil
      return fs, read_only
    end
  end
  return "apfs", nil
end

local function update_disk_rows()
  sbar.exec(
    [[
      df -k / "$HOME"
      printf '__MOUNT__\n'
      mount
    ]],
    function(output)
      local df_output, mount_output = output:match "^(.-)\n__MOUNT__\n(.*)$"
      if not df_output or not mount_output then
        return
      end

      local seen_home = false
      for line in df_output:gmatch "[^\n]+" do
        if line:match "^/dev/" then
          local fields = {}
          for field in line:gmatch "%S+" do
            table.insert(fields, field)
          end

          local total = tonumber(fields[2]) and tonumber(fields[2]) * 1024
          local available = tonumber(fields[4]) and tonumber(fields[4]) * 1024
          local mountpoint = fields[#fields]

          if total and available and total > 0 then
            local used = total - available
            local percent = math.floor(used * 100 / total + 0.5)
            local fs, read_only = mount_info(mount_output, mountpoint)

            if mountpoint == "/" then
              set_row(
                root_row,
                string.format(
                  "Disk (/): %s / %s (%d%%) - %s%s",
                  format_bytes(used),
                  format_bytes(total),
                  percent,
                  fs,
                  volume_types(read_only)
                )
              )
            elseif not seen_home then
              seen_home = true
              set_row(
                home_row,
                string.format(
                  "Disk ($HOME): %s / %s (%d%%) - %s%s",
                  format_bytes(used),
                  format_bytes(total),
                  percent,
                  fs,
                  volume_types(read_only)
                )
              )
            end
          end
        end
      end
    end
  )
end

local function parse_diskutil_info(output)
  local values = {}
  for line in output:gmatch "[^\n]+" do
    local key, value = line:match "^%s*(.-):%s*(.-)%s*$"
    if key and value then
      values[key] = value
    end
  end

  local name = values["Device / Media Name"] or "Physical Disk"
  if name == "Disk Image" then
    name = "Apple Disk Image Media"
  elseif not name:match "Media$" then
    name = name .. " Media"
  end

  local bytes = tonumber((values["Disk Size"] or ""):match "%((%d+) Bytes%)") or 0
  local kind = values["Virtual"] == "Yes" and "Virtual"
    or (values["Solid State"] == "Yes" and "SSD" or "HDD")
  local fixed = values["Removable Media"] or "Fixed"
  local read_only = values["Media Read-Only"] == "Yes" and "Read-only" or nil
  local types = kind .. ", " .. fixed .. (read_only and ", " .. read_only or "")
  local temperature = values["Temperature"] and (" - " .. values["Temperature"]) or ""

  return string.format(
    "Physical Disk (%s): %s [%s]%s",
    name,
    format_bytes(bytes),
    types,
    temperature
  )
end

local function update_physical_rows()
  for _, row in ipairs(physical_rows) do
    row:set { drawing = false }
  end

  sbar.exec("diskutil list", function(output)
    local devices = {}
    for line in output:gmatch "[^\n]+" do
      local device, kind = line:match "^/dev/(disk%d+) %((.-)%)"
      if device and (kind:match "physical" or kind:match "disk image") then
        table.insert(devices, device)
      end
    end

    for index, device in ipairs(devices) do
      local row = physical_rows[index]
      if row then
        sbar.exec("diskutil info /dev/" .. device, function(info)
          set_row(row, parse_diskutil_info(info))
        end)
      end
    end
  end)
end

local function update_details()
  update_swap_row()
  update_disk_rows()
  update_physical_rows()
end

ssd_volume:subscribe({ "routine", "forced", "system_woke" }, function(_)
  sbar.exec(
    [[
    df -k "$HOME" | awk 'NR==2 {
      free=$4 * 1024
      total=$2 * 1024
      pct=(total > 0) ? (free / total) * 100 : 0
      printf "%d %.1f %.1f\n", pct, free / 1024 / 1024 / 1024, total / 1024 / 1024 / 1024
    }'
  ]],
    function(output)
      if output then
        local free_pct_s = output:match "^%s*(%d+)%s+[%d%.]+%s+[%d%.]+"
        local free_pct = tonumber(free_pct_s) or 0
        local used_pct = 100 - free_pct
        local Icon = "󰅚"
        local Color = free_space_color(free_pct)
        for _, threshold in ipairs(icon_thresholds) do
          if free_pct >= threshold.min then
            Icon = threshold.icon
            break
          end
        end

        ssd_volume:set {
          label = {
            string = string.format("SSD %d%%", used_pct),
            color = Color,
          },
          icon = {
            string = Icon,
            color = Color,
          },
          background = {
            border_color = settings.theme.border,
          },
        }
      end
    end
  )
end)

ssd_volume:subscribe("mouse.clicked", function()
  utils.popup_toggle(ssd_volume, update_details)
end)

ssd_volume:subscribe("mouse.exited.global", function()
  utils.popup_hide(ssd_volume)
end)
