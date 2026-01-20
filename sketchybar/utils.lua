local utils = {}

function utils.get_wifi_interface()
  local handle =
    io.popen "networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}'"
  local result = handle:read "*a"
  handle:close()
  return result:gsub("%s+", "") -- trim whitespace
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

return utils
