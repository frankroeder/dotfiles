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

local main_screen_width = math.floor(
  tonumber(
    popen_line(
      "osascript -l JavaScript -e 'ObjC.import(\"AppKit\"); "
        .. "Math.floor($.NSScreen.mainScreen.frame.size.width)' 2>/dev/null"
    )
  ) or screen_width
)

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

local function ingest_display_rows()
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

local displays = ingest_display_rows()

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

local main_notch = (main_index == builtin_index and notch_width > 0) and notch_width or 0

local function map_yabai_index(yabai_index)
  if not yabai_index then
    return nil
  end
  for _, row in ipairs(displays) do
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
  return match_width(width) or yabai_index
end

local function focused_index()
  -- `--display focused` is not a valid yabai DISPLAY_SEL; pick the has-focus display instead.
  local yabai_index = tonumber(
    popen_line [[yabai -m query --displays 2>/dev/null | /usr/bin/jq -r 'map(select(.["has-focus"]))[0].index // empty' 2>/dev/null]]
  )
  return map_yabai_index(yabai_index) or main_index
end

return {
  screen_width = screen_width,
  notch_width = notch_width,
  builtin_index = builtin_index,
  external_index = external_index,
  displays = displays,
  main_index = main_index,
  main_width = main_width,
  main_notch = main_notch,
  focused_index = focused_index,
}