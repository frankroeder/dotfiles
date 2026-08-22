-- Pure skhdrc → shortcut-list parser (no sbar). Turns binding lines + their
-- preceding comments into sections of { desc, keys } rows for the popup.
-- Tested by sketchybar/top/tests/shortcuts_logic_test.lua.

local logic = {}

local MOD_ORDER = { "fn", "ctrl", "alt", "shift", "cmd" }
local MOD_GLYPH = { fn = "fn", ctrl = "⌃", alt = "⌥", shift = "⇧", cmd = "⌘" }
local MOD_EXPAND = {
  meh = { "ctrl", "alt", "shift" },
  hyper = { "ctrl", "alt", "shift", "cmd" },
}
local MOD_WORDS = { fn = true, ctrl = true, alt = true, shift = true, cmd = true }
for word in pairs(MOD_EXPAND) do
  MOD_WORDS[word] = true
end

local KEY_GLYPH = {
  space = "Space",
  left = "←",
  right = "→",
  up = "↑",
  down = "↓",
  ["return"] = "↩",
  tab = "⇥",
  escape = "⎋",
  delete = "⌫",
}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function capitalize(s)
  return (s:gsub("^%l", string.upper))
end

-- Comment content that is pure box/banner decoration (##### or =====).
local function is_decoration(content)
  return content:match "^[#=%-%s]*$" ~= nil
end

-- "# fn + alt - n : yabai ..." — a commented-out binding, not a description.
local function is_disabled_binding(content)
  local first = content:match "^(%a+)"
  if not first or not MOD_WORDS[first:lower()] then
    return false
  end
  return content:match "%-%s*%S+%s*:" ~= nil
end

-- Parse "fn + ctrl - y" → glyph chord prefix ("fn⌃") or nil when invalid.
local function parse_mods(modstr)
  local present = {}
  for token in modstr:gmatch "[^%+%s]+" do
    local word = token:lower()
    if MOD_EXPAND[word] then
      for _, m in ipairs(MOD_EXPAND[word]) do
        present[m] = true
      end
    elseif MOD_GLYPH[word] then
      present[word] = true
    else
      return nil
    end
  end
  local out = {}
  for _, m in ipairs(MOD_ORDER) do
    if present[m] then
      out[#out + 1] = MOD_GLYPH[m]
    end
  end
  return table.concat(out)
end

local function parse_binding(line)
  local lhs, cmd = line:match "^([^:]+):%s*(.*)$"
  if not lhs then
    return nil
  end
  local modstr, key = lhs:match "^(.-)%-%s*(%S+)%s*$"
  if not modstr then
    return nil
  end
  local mods = parse_mods(modstr)
  if not mods or cmd == "" then
    return nil
  end
  return { mods = mods, key = key:lower(), cmd = trim(cmd) }
end

-- Strip implementation noise from a comment: "(u)p" hints, "— …" and
-- "(signal …)" / ": …" tails. Keeps the human-facing half.
function logic.pretty_desc(s)
  s = trim(s)
  s = s:gsub("%((%a)%)", "%1")
  local dash = s:find("—", 1, true)
  if dash then
    s = s:sub(1, dash - 1)
  end
  local paren = s:find(" (", 1, true)
  if paren then
    s = s:sub(1, paren - 1)
  end
  local colon = s:find(": ", 1, true)
  if colon then
    s = s:sub(1, colon - 1)
  end
  s = trim(s):gsub("[%.;,]+$", "")
  return capitalize(s)
end

-- Best-effort description for bindings that carry no comment.
function logic.derive_desc(cmd)
  local url = cmd:match "vicinae://launch/(%S+)"
  if url then
    url = url:gsub('["\']$', "")
    local words, seen = {}, {}
    for seg in url:gmatch "[^/]+" do
      if not seg:match "[@%.]" then
        for w in seg:gmatch "[^%-]+" do
          local lw = w:lower()
          if not seen[lw] then
            seen[lw] = true
            words[#words + 1] = lw
          end
        end
      end
    end
    if #words == 0 then
      words = { (url:match "([^/]+)/?$" or url):lower() }
    end
    return capitalize(table.concat(words, " "))
  end
  if cmd:match "systempreferences" then
    return "System Settings"
  end
  local app = cmd:match 'open%s+%-a%s+"([^"]+)"' or cmd:match "open%s+%-a%s+([%w%.]+)"
  if app then
    return capitalize(app)
  end
  app = cmd:match '/Applications/([^/"]+)%.app'
  if app then
    return app
  end
  local arg = cmd:match 'toggle_app%.bash"%s*"([^"]+)"'
  if arg then
    local var = arg:match "^%$([%u_]+)$"
    if var then
      arg = capitalize(var:gsub("_NAME$", ""):lower())
    end
    return "Toggle " .. arg
  end
  local script = cmd:match 'bash%s+"[^"]*/([%w%-_]+)"'
  if script then
    return capitalize(script:gsub("%-", " "))
  end
  if cmd:match "^yabai %-m space %-%-focus %d" then
    return "Focus space"
  end
  return capitalize(cmd:match "^(%S+)" or cmd)
end

local function display_key(key)
  if KEY_GLYPH[key] then
    return KEY_GLYPH[key]
  end
  return key:upper()
end

-- "1".."9" consecutive → "1–9"; else "H/J/K/L".
local function display_keys(keys)
  if #keys > 1 then
    local nums = {}
    for i, k in ipairs(keys) do
      nums[i] = k:match "^%d$" and tonumber(k) or nil
    end
    local consecutive = nums[1] ~= nil
    for i = 2, #keys do
      if not nums[i] or nums[i] ~= nums[i - 1] + 1 then
        consecutive = false
        break
      end
    end
    if consecutive then
      return keys[1] .. "–" .. keys[#keys]
    end
  end
  local out = {}
  for i, k in ipairs(keys) do
    out[i] = display_key(k)
  end
  return table.concat(out, "/")
end

local function chord(mods, keys)
  local k = display_keys(keys)
  if mods == "" then
    return k
  end
  return mods .. " " .. k
end

-- Group consecutive entries that describe one action, resolve descriptions,
-- then merge adjacent groups that ended up identical (fn 1–5 + fn 6–9).
local function build_rows(entries)
  local groups = {}
  for _, e in ipairs(entries) do
    local norm = e.cmd:gsub("%d+", "#")
    local prev = groups[#groups]
    local joins = prev
      and prev.mods == e.mods
      and (
        (e.desc ~= nil and e.desc == prev.desc)
        or (e.desc == nil and prev.desc == nil and norm == prev.norm)
      )
    if joins then
      prev.keys[#prev.keys + 1] = e.key
    else
      groups[#groups + 1] = { mods = e.mods, keys = { e.key }, desc = e.desc, norm = norm, cmd = e.cmd }
    end
  end
  for _, g in ipairs(groups) do
    g.text = g.desc and logic.pretty_desc(g.desc) or logic.derive_desc(g.cmd)
  end
  local merged = {}
  for _, g in ipairs(groups) do
    local prev = merged[#merged]
    if prev and prev.mods == g.mods and prev.text == g.text then
      for _, k in ipairs(g.keys) do
        prev.keys[#prev.keys + 1] = k
      end
    else
      merged[#merged + 1] = g
    end
  end
  local rows = {}
  for _, g in ipairs(merged) do
    rows[#rows + 1] = { desc = g.text, keys = chord(g.mods, g.keys) }
  end
  return rows
end

-- text → { { title, rows = { { desc, keys } } } }
function logic.parse(text)
  -- Join continuation lines (trailing backslash) into logical lines.
  local lines = {}
  local acc = nil
  for line in (text .. "\n"):gmatch "(.-)\n" do
    acc = acc and (acc .. " " .. trim(line)) or line
    if acc:match "\\%s*$" then
      acc = acc:gsub("\\%s*$", "")
    else
      lines[#lines + 1] = acc
      acc = nil
    end
  end

  local sections = {}
  local current = { title = "General", entries = {} }
  local pending, last_desc, last_mods = nil, nil, nil

  local function flush()
    if #current.entries > 0 then
      sections[#sections + 1] = current
    end
  end

  local function comment_content(line)
    local t = trim(line)
    if t:sub(1, 1) ~= "#" then
      return nil
    end
    -- Strip ALL leading hash runs ("# # comment" → "comment").
    return t:match "^[#%s]*(.-)%s*$" or ""
  end

  local i = 1
  while i <= #lines do
    local line = trim(lines[i])
    if line == "" then
      pending, last_desc, last_mods = nil, nil, nil
    elseif line:sub(1, 2) == "#!" then
      -- shebang
    elseif line:sub(1, 1) == "#" then
      local content = comment_content(line)
      if is_decoration(content) then
        pending, last_desc, last_mods = nil, nil, nil
        -- Boxed section header: deco / "#  Title  #" / deco.
        local mid = lines[i + 1] and comment_content(lines[i + 1])
        local bot = lines[i + 2] and comment_content(lines[i + 2])
        if mid and bot and is_decoration(bot) then
          local title = trim(mid:gsub("%s*#+%s*$", ""))
          if title ~= "" and not is_decoration(title) and not title:find(":", 1, true) then
            flush()
            current = { title = title, entries = {} }
            i = i + 2
          end
        end
      elseif is_disabled_binding(content) then
        -- Commented-out binding: skip, keep surrounding comment context.
      else
        pending, last_desc, last_mods = content, nil, nil
      end
    else
      local entry = parse_binding(line)
      if entry then
        if pending then
          entry.desc = pending
          pending = nil
        elseif last_mods == entry.mods then
          entry.desc = last_desc
        end
        last_desc, last_mods = entry.desc, entry.mods
        current.entries[#current.entries + 1] = entry
      end
    end
    i = i + 1
  end
  flush()

  local out = {}
  for _, sec in ipairs(sections) do
    out[#out + 1] = { title = sec.title, rows = build_rows(sec.entries) }
  end
  return out
end

return logic
