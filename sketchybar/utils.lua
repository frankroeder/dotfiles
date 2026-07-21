local utils = {}
local app_icon_indexes = setmetatable({}, { __mode = "k" })

function utils.shell_quote(value)
  return "'" .. tostring(value):gsub("'", [['"'"']]) .. "'"
end

-- sketchybar mouse.scrolled: prefer SCROLL_DELTA; INFO is a fallback.
function utils.scroll_delta(env)
  for _, key in ipairs { "SCROLL_DELTA", "INFO" } do
    local raw = env[key]
    if raw ~= nil and raw ~= "" then
      local n = tonumber(raw) or tonumber(tostring(raw):match "(-?%d+)")
      if n and n ~= 0 then
        return n
      end
    end
  end
  return 0
end

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
  local query = item:query()
  local opening = not query or not query.popup or query.popup.drawing == "off"

  if opening and update_fn then
    update_fn()
  end

  -- Lazy popups (e.g. brew) have no query.popup until children are created.
  if not query or not query.popup then
    item:set { popup = { drawing = "toggle" } }
  else
    item:set { popup = { drawing = opening } }
  end
end

function utils.popup_hide(item)
  item:set { popup = { drawing = false } }
end

function utils.clipboard_copy(item_name, icons)
  if not item_name or item_name == "" then
    return
  end
  local q = sbar.query(item_name)
  local label = q and q.label and q.label.value
  if not label then
    return
  end
  sbar.exec('echo "' .. label .. '" | pbcopy')
  sbar.set(item_name, { label = { string = icons.clipboard, align = "center" } })
  sbar.delay(1, function()
    sbar.set(item_name, { label = { string = label, align = "right" } })
  end)
end

function utils.color_gradient(value, thresholds)
  local colors = require "colors"
  thresholds = thresholds
    or {
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
  return colors.subtext1
end

function utils.lookup_app_icon(app, app_icons)
  if not app or app == "" then
    return app_icons["Default"]
  end

  local by_lower = app_icon_indexes[app_icons]
  if not by_lower then
    by_lower = {}
    for name, icon in pairs(app_icons) do
      by_lower[name:lower()] = icon
    end
    app_icon_indexes[app_icons] = by_lower
  end

  local trimmed = tostring(app):gsub("^%s+", ""):gsub("%s+$", "")
  local candidates = {
    trimmed,
    (trimmed:gsub("%.app$", "")),
    (trimmed:gsub(" Browser$", "")),
    (trimmed:gsub(" %- .*$", "")),
  }

  for _, candidate in ipairs(candidates) do
    local icon = app_icons[candidate] or by_lower[candidate:lower()]
    if icon then
      return icon
    end
  end

  return app_icons["Default"]
end

function utils.exec_safe(cmd, callback)
  sbar.exec(cmd, function(result)
    if result and result ~= "" then
      callback(result)
    end
  end)
end

return utils
