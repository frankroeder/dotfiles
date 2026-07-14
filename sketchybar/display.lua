-- Built-in display geometry for notch-aware bars.
-- Uses the internal screen (not NSScreen.mainScreen) so external-primary setups stay correct.
--
--   screen_width     – built-in logical width
--   notch_width      – built-in notch width
--   builtin_index    – sketchybar arrangement-id for the built-in display
--   external_index   – first non-built-in arrangement-id (nil if none)
--   displays         – sketchybar display rows { index, direct_id, width }
--   main_index       – sketchybar arrangement-id for NSScreen.mainScreen
--   main_width       – logical width of main_index
--   main_notch       – notch width on main_index (0 when main is external)
--   focused_index()  – sketchybar arrangement-id for yabai's focused display
--   refresh()        – re-probe notch + display rows (hotplug / resolution)

local SKETCHYBAR_BINS = {
  "/opt/homebrew/bin/sketchybar-top",
  "/opt/homebrew/bin/sketchybar",
  "/opt/homebrew/bin/sketchybar-island",
}

local function popen_line(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end
  local line = handle:read "*l"
  handle:close()
  if line and line ~= "" then
    return line
  end
  return nil
end

local function popen_all(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return ""
  end
  local raw = handle:read "*a" or ""
  handle:close()
  return raw
end

-- Notch = gap between auxiliaryTopLeft/Right areas. Without side areas, n == w
-- (false notch on external monitors); require both flanks and n < 40% of width.
local NOTCH_JS = "osascript -l JavaScript -e '"
  .. 'ObjC.import("AppKit");'
  .. "function notchOf(s){"
  .. "var w=s.frame.size.width;"
  .. "var L=s.auxiliaryTopLeftArea.size.width;"
  .. "var R=s.auxiliaryTopRightArea.size.width;"
  .. "var n=w-L-R;"
  .. "if(L>1&&R>1&&n>50&&n<w*0.4)return Math.floor(n);"
  .. "return 0;}"
  .. "var screens=$.NSScreen.screens;"
  .. "var sw=0,nw=0;"
  .. "for(var i=0;i<screens.length;i++){"
  .. "var s=screens.objectAtIndex(i);"
  .. "var n=notchOf(s);"
  .. "if(n>0){sw=Math.floor(s.frame.size.width);nw=n;break;}"
  .. "}"
  .. "if(sw===0){"
  .. "for(var j=0;j<screens.length;j++){"
  .. "var s=screens.objectAtIndex(j);"
  .. "var name=ObjC.unwrap(s.localizedName)||\"\";"
  .. "if(name.indexOf(\"Built-in\")>=0){"
  .. "sw=Math.floor(s.frame.size.width);nw=notchOf(s);break;}"
  .. "}"
  .. "}"
  .. "if(sw===0){"
  .. "var m=$.NSScreen.mainScreen;"
  .. "sw=Math.floor(m.frame.size.width);nw=notchOf(m);"
  .. "}"
  .. "sw+\",\"+nw"
  .. "' 2>/dev/null"

local MAIN_W_JS = "osascript -l JavaScript -e 'ObjC.import(\"AppKit\"); "
  .. "Math.floor($.NSScreen.mainScreen.frame.size.width)' 2>/dev/null"

local function probe_notch()
  local out = popen_line(NOTCH_JS) or ""
  local sw, nw = out:match("([%d.]+),([%d.]+)")
  local screen_width = math.floor(tonumber(sw) or 1728)
  local notch_width = math.floor(tonumber(nw) or 0)
  if notch_width <= 50 or notch_width >= screen_width * 0.4 then
    notch_width = 0
  end
  return screen_width, notch_width
end

local function probe_main_width(fallback)
  return math.floor(tonumber(popen_line(MAIN_W_JS)) or fallback)
end

local function query_sketchybar_displays()
  for _, bin in ipairs(SKETCHYBAR_BINS) do
    local raw = popen_all(bin .. " --query displays 2>/dev/null")
    if raw:find("arrangement%-id", 1, true) then
      return raw
    end
  end
  return ""
end

local function parse_sketchybar_rows(raw)
  local rows = {}
  for block in raw:gmatch "{[^}]-}" do
    local index = tonumber(block:match '"arrangement%-id":(%d+)')
    local direct_id = tonumber(block:match '"direct%-id":(%d+)')
    local width = tonumber(block:match '"w":([%d%.]+)')
    if index then
      table.insert(rows, {
        index = index,
        direct_id = direct_id or index,
        width = width and math.floor(width) or nil,
      })
    end
  end
  return rows
end

local function query_yabai_rows()
  local raw = popen_all "yabai -m query --displays 2>/dev/null"
  local rows = {}
  for block in raw:gmatch "{[^}]-}" do
    local index = tonumber(block:match '"index":(%d+)')
    local width = tonumber(block:match '"w":([%d%.]+)')
    if index then
      table.insert(rows, {
        index = index,
        width = width and math.floor(width) or nil,
      })
    end
  end
  return rows
end

local function ingest_display_rows(screen_width)
  local rows = parse_sketchybar_rows(query_sketchybar_displays())
  if #rows > 0 then
    return rows
  end

  local yabai_rows = query_yabai_rows()
  for _, row in ipairs(yabai_rows) do
    table.insert(rows, {
      index = row.index,
      direct_id = row.index,
      width = row.width,
    })
  end
  if #rows > 0 then
    return rows
  end

  return {
    {
      index = 1,
      direct_id = 1,
      width = screen_width,
    },
  }
end

local M = {}

local function recompute()
  local screen_width, notch_width = probe_notch()
  local main_screen_width = probe_main_width(screen_width)
  local displays = ingest_display_rows(screen_width)

  local function match_width(width)
    if not width then
      return nil
    end
    for _, row in ipairs(displays) do
      if row.width and math.abs(row.width - width) < 2 then
        return row.index
      end
    end
    return nil
  end

  local builtin_index = match_width(screen_width) or displays[1].index
  local external_index = nil
  for _, row in ipairs(displays) do
    if row.index ~= builtin_index then
      external_index = row.index
      break
    end
  end

  local main_index = match_width(main_screen_width) or builtin_index
  local main_width = screen_width
  for _, row in ipairs(displays) do
    if row.index == main_index and row.width then
      main_width = row.width
      break
    end
  end

  M.screen_width = screen_width
  M.notch_width = notch_width
  M.builtin_index = builtin_index
  M.external_index = external_index
  M.displays = displays
  M.main_index = main_index
  M.main_width = main_width
  M.main_notch = (main_index == builtin_index and notch_width > 0) and notch_width or 0
end

local function map_yabai_index(yabai_index)
  if not yabai_index then
    return nil
  end
  for _, row in ipairs(M.displays) do
    if row.index == yabai_index or row.direct_id == yabai_index then
      return row.index
    end
  end
  local yabai_rows = query_yabai_rows()
  local width = nil
  for _, row in ipairs(yabai_rows) do
    if row.index == yabai_index then
      width = row.width
      break
    end
  end
  if not width then
    return yabai_index
  end
  for _, row in ipairs(M.displays) do
    if row.width and math.abs(row.width - width) < 2 then
      return row.index
    end
  end
  return yabai_index
end

function M.focused_index()
  -- Single display: skip the blocking yabai+jq query (pills appear faster).
  if #M.displays == 1 then
    return M.displays[1].index
  end
  -- `--display focused` is not a valid yabai DISPLAY_SEL; pick the has-focus display instead.
  local yabai_index = tonumber(
    popen_line [[yabai -m query --displays 2>/dev/null | /usr/bin/jq -r 'map(select(.["has-focus"]))[0].index // empty' 2>/dev/null]]
  )
  return map_yabai_index(yabai_index) or M.main_index
end

-- Re-probe notch + arrangement rows (display_change / hotplug).
function M.refresh()
  recompute()
  return M
end

recompute()

return M
