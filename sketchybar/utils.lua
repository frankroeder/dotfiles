local utils = {}

function utils.get_wifi_interface()
  local handle =
    io.popen "networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}'"
  local result = handle:read "*a"
  handle:close()
  return result:gsub("%s+", "")
end

function utils.get_primary_interface()
  -- Prioritize physical interfaces (en*) over VPN tunnels (utun*)
  local handle = io.popen "scutil --nwi | awk '/^ *en[0-9]+ :/ { print $1; exit }'"
  local result = handle:read "*a"
  handle:close()
  if result and result ~= "" then
    return result:gsub("%s+", "")
  end
  return "en0"
end

function utils.popup_toggle(item, update_fn)
  local should_draw = item:query().popup.drawing == "off"
  item:set { popup = { drawing = should_draw } }
  if should_draw and update_fn then
    update_fn()
  end
end

function utils.popup_hide(item)
  item:set { popup = { drawing = false } }
end

function utils.clipboard_copy(item_name, icons)
  local label = sbar.query(item_name).label.value
  sbar.exec('echo "' .. label .. '" | pbcopy')
  sbar.set(item_name, { label = { string = icons.clipboard, align = "center" } })
  sbar.delay(1, function()
    sbar.set(item_name, { label = { string = label, align = "right" } })
  end)
end

function utils.color_gradient(value, thresholds)
  local colors = require "colors"
  thresholds = thresholds or {
    { min = 80, color = colors.red },
    { min = 60, color = colors.orange },
    { min = 30, color = colors.yellow },
    { min = 0, color = colors.blue },
  }
  for _, t in ipairs(thresholds) do
    if value >= t.min then
      return t.color
    end
  end
  return colors.white
end

function utils.exec_safe(cmd, callback)
  sbar.exec(cmd, function(result)
    if result and result ~= "" then
      callback(result)
    end
  end)
end

return utils
