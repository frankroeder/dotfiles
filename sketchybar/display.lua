-- Built-in display geometry for notch-aware bars.
-- Uses the internal screen (not NSScreen.mainScreen) so external-primary setups stay correct.
--
--   screen_width     – built-in logical width
--   notch_width      – built-in notch width
--   builtin_index    – sketchybar arrangement-id for the built-in display
--   external_index   – first non-built-in arrangement-id (nil if none)

local handle = io.popen(
  "osascript -l JavaScript -e '"
    .. 'ObjC.import("AppKit");'
    .. "var screens=$.NSScreen.screens;"
    .. "var sw=0,nw=0;"
    .. "for(var i=0;i<screens.length;i++){"
    .. "var s=screens.objectAtIndex(i);"
    .. "var w=s.frame.size.width;"
    .. "var n=w-s.auxiliaryTopLeftArea.size.width"
    .. "-s.auxiliaryTopRightArea.size.width;"
    .. "if(n>50){sw=Math.floor(w);nw=Math.floor(n);break;}"
    .. "}"
    .. "if(sw===0){"
    .. "for(var j=0;j<screens.length;j++){"
    .. "var s=screens.objectAtIndex(j);"
    .. "var name=ObjC.unwrap(s.localizedName)||\"\";"
    .. "if(name.indexOf(\"Built-in\")>=0){"
    .. "sw=Math.floor(s.frame.size.width);"
    .. "nw=Math.floor(sw-s.auxiliaryTopLeftArea.size.width"
    .. "-s.auxiliaryTopRightArea.size.width);"
    .. "break;}"
    .. "}"
    .. "}"
    .. "if(sw===0){"
    .. "var m=$.NSScreen.mainScreen;"
    .. "sw=Math.floor(m.frame.size.width);"
    .. "nw=Math.floor(sw-m.auxiliaryTopLeftArea.size.width"
    .. "-m.auxiliaryTopRightArea.size.width);"
    .. "}"
    .. "sw+\",\"+nw"
    .. "' 2>/dev/null"
)
local out = handle and handle:read "*l" or ""
if handle then
  handle:close()
end

local sw, nw = out:match("([%d.]+),([%d.]+)")
local screen_width = math.floor(tonumber(sw) or 1728)
local notch_width = math.floor(tonumber(nw) or 162)

local function sketchybar_display_ids(width)
  local builtin_index = 1
  local external_index = nil
  local ids = {}

  local f = io.popen("/opt/homebrew/bin/sketchybar -m --query displays 2>/dev/null")
  if not f then
    return builtin_index, external_index
  end
  local raw = f:read "*a" or ""
  f:close()

  for block in raw:gmatch "{[^}]-}" do
    local id = tonumber(block:match '"arrangement%-id":(%d+)')
    local w = tonumber(block:match '"w":([%d%.]+)')
    if id then
      table.insert(ids, id)
      if w and math.abs(w - width) < 2 then
        builtin_index = id
      end
    end
  end

  for _, id in ipairs(ids) do
    if id ~= builtin_index then
      external_index = id
      break
    end
  end

  return builtin_index, external_index
end

local builtin_index, external_index = sketchybar_display_ids(screen_width)

return {
  screen_width = screen_width,
  notch_width = notch_width,
  builtin_index = builtin_index,
  external_index = external_index,
}