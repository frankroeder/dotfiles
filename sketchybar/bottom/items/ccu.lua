-- Credits to https://github.com/TaterDoge/dotfiles/tree/main
local colors = require "colors"
local icons = require "icons"
local settings = require "settings"
local ui = require "ui"

local theme = settings.theme
local metrics = settings.ui

-- Fixed columns: title | bar | value.
-- Item padding must stay 0 (horizontal pack advances x by it). Gaps between
-- title/bar/value use icon/label padding inside fixed column widths instead.
local pad = 10
local col_gap = 10
local title_w = 108 -- fits "Session (5h)" / "Weekly Fable"
local bar_w = 100
local value_w = 180 -- fits "130% used  01.08. 02:00" / "69%  3h 5m [active]"
local bar_h = 6
local row_h = metrics.popup_row_height
local content_w = title_w + bar_w + value_w
local popup_width = content_w + pad * 2
local helpers = os.getenv "HOME" .. "/.dotfiles/sketchybar/helpers"

-- Horizontal popup: width=0 rows stack via y_offset; link buttons share bottom.
-- Rows: Session (5h), Week (7d), Weekly Fable, Grok (30d), links.
local row_gap = 2
local step = row_h + row_gap
local popup_h = row_h * 5 + row_gap * 4 + 10
local y_session = 2 * step
local y_weekly = 1 * step
local y_fable = 0
local y_grok = -1 * step
local y_links = -2 * step
local btn_gap = 6
local btn_w = math.floor((content_w - btn_gap) / 2)

local accent_session = colors.mauve
local accent_weekly = colors.blue
local accent_fable = colors.pink
local accent_grok = colors.teal
local last = { session = nil, weekly = nil, fable = nil, grok = nil }

local ccu = ui.add_capsule("widgets.ccu", {
  position = "left",
  icon = { drawing = false },
  label = {
    string = "CCu",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_right = 10,
  },
  popup = {
    align = "center",
    horizontal = true,
    height = popup_h,
    background = ui.popup(),
  },
})

-- Mono for titles+values so fixed icon/label widths actually column-align.
local title_font = {
  family = settings.font.numbers,
  style = settings.font.style_map["Semibold"],
  size = 12.0,
}
local value_font = {
  family = settings.font.numbers,
  size = 11.0,
}

local function track_color(accent)
  return colors.with_alpha(accent, colors.is_dark and 0.20 or 0.14)
end

-- Color by used % (high = bad), even when UI shows remaining.
local function usage_color(used)
  if used == nil then
    return theme.text_muted
  end
  if used >= 90 then
    return theme.critical
  end
  if used >= 75 then
    return colors.orange
  end
  if used >= 50 then
    return theme.warn
  end
  return theme.text_muted
end

local function metric_row(name, title, accent, y)
  return sbar.add("slider", name, bar_w, {
    position = "popup." .. ccu.name,
    -- width=0 + zero item pads: pack length 0 so every row shares the same x.
    width = 0,
    padding_left = 0,
    padding_right = 0,
    y_offset = y,
    icon = {
      string = title,
      width = title_w,
      align = "right",
      padding_left = 0,
      padding_right = col_gap,
      font = title_font,
      color = accent,
    },
    label = {
      string = "…",
      width = value_w,
      align = "left",
      padding_left = col_gap,
      padding_right = 0,
      font = value_font,
      color = theme.text_muted,
    },
    slider = {
      percentage = 0,
      width = bar_w,
      highlight_color = accent,
      background = {
        height = bar_h,
        corner_radius = bar_h / 2,
        color = track_color(accent),
      },
      knob = { drawing = false, string = "" },
    },
    background = { drawing = false, height = row_h },
  })
end

local function clamp_pct(percent)
  if percent == nil then
    return 0
  end
  local n = math.floor(percent + 0.5)
  if n < 0 then
    return 0
  end
  if n > 100 then
    return 100
  end
  return n
end

local function set_percent(item, accent, percent)
  item:set {
    slider = {
      percentage = clamp_pct(percent),
      width = bar_w,
      highlight_color = accent,
      background = {
        height = bar_h,
        corner_radius = bar_h / 2,
        color = track_color(accent),
      },
      knob = { drawing = false, string = "" },
    },
  }
end

sbar.add("item", "widgets.ccu.inset", {
  position = "popup." .. ccu.name,
  width = pad,
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

local session_row = metric_row("widgets.ccu.session", "Session (5h)", accent_session, y_session)
local weekly_row = metric_row("widgets.ccu.weekly", "Week (7d)", accent_weekly, y_weekly)
local fable_row = metric_row("widgets.ccu.fable", "Weekly Fable", accent_fable, y_fable)
local grok_row = metric_row("widgets.ccu.grok", "Grok (30d)", accent_grok, y_grok)

local function link_button(name, title, url, pad_l, pad_r)
  return sbar.add("item", name, {
    position = "popup." .. ccu.name,
    width = btn_w,
    align = "center",
    padding_left = pad_l,
    padding_right = pad_r,
    y_offset = y_links,
    icon = { drawing = false },
    label = {
      string = icons.external_link .. "  " .. title,
      color = theme.text_muted,
      font = value_font,
      align = "center",
      width = btn_w,
      padding_left = 0,
      padding_right = 0,
    },
    background = ui.button { height = row_h },
    click_script = "open '" .. url .. "'",
  })
end

local claude_link = link_button(
  "widgets.ccu.claude_link",
  "Claude",
  "https://claude.ai/settings/usage",
  0,
  math.floor(btn_gap / 2)
)
local grok_link = link_button(
  "widgets.ccu.grok_link",
  "Grok",
  "https://grok.com/?_s=usage",
  math.ceil(btn_gap / 2),
  0
)

local function parse_lua_table(lit, tag)
  if not lit or lit == "" then
    return { error = "empty_response" }
  end
  local fn, err = load("return " .. lit, tag, "t", {})
  if not fn then
    return { error = "parse_error" }
  end
  local ok, result = pcall(fn)
  if not ok or type(result) ~= "table" then
    return { error = "invalid_response" }
  end
  if result.error then
    return { error = result.error }
  end
  return result
end

local function window_fields(block)
  if not block or type(block) ~= "table" then
    return nil
  end
  local used = tonumber(block.used)
  local remaining = tonumber(block.remaining)
  if used == nil and remaining == nil then
    return nil
  end
  if used == nil then
    used = 100 - remaining
  end
  if remaining == nil then
    remaining = math.max(0, 100 - used)
  end
  return {
    used = used,
    remaining = math.max(0, remaining),

    reset_text = block.reset_text,
    label = block.label,
    kind = block.kind,
    model = block.model,
    active = block.active == true,
  }
end

local function get_claude_usage(callback)
  sbar.exec("python3 " .. helpers .. "/claude_usage.py", function(lit)
    local result = parse_lua_table(lit, "ccu_claude")
    if result.error then
      callback(result)
      return
    end
    callback {
      session = window_fields(result.session),
      weekly = window_fields(result.weekly),
      scoped = window_fields(result.scoped),
    }
  end)
end

local function get_grok_usage(callback)
  sbar.exec("python3 " .. helpers .. "/grok_usage.py", function(lit)
    local result = parse_lua_table(lit, "ccu_grok")
    if result.error then
      callback(result)
      return
    end
    local used = tonumber(result.utilization)
    local remaining = tonumber(result.remaining)
    if remaining == nil and used ~= nil then
      remaining = math.max(0, 100 - used)
    end
    callback {
      utilization = used,
      remaining = remaining,
      resets_at = result.resets_at_de or result.resets_at,
    }
  end)
end

-- "2026-07-09 11:19 (CEST)" → "09.07. 11:19" (Grok absolute date fallback)
local function short_reset(s)
  if not s or s == "" then
    return nil
  end
  local m, d, t = s:match "%d%d%d%d%-(%d%d)%-(%d%d) (%d%d:%d%d)"
  if m then
    return string.format("%s.%s. %s", d, m, t)
  end
  return s
end

-- Remaining % + relative reset; [active] = currently counting window (CLI style).
local function format_remaining(win)
  if not win or win.remaining == nil then
    return "—"
  end
  local text = string.format("%3.0f%%", win.remaining)
  if win.reset_text and win.reset_text ~= "" then
    text = text .. "  " .. win.reset_text
  end
  if win.active then
    text = text .. " [active]"
  end
  return text
end

-- Fixed CLI-style titles (window length / weekly scope). Scoped uses model name.
local function row_title(win, fallback)
  if not win then
    return fallback
  end
  if win.kind == "weekly_scoped" or (win.label and win.label ~= "Session" and win.label ~= "Weekly") then
    local model = win.model or win.label
    if model and model ~= "" and model ~= "Scoped" then
      return "Weekly " .. model
    end
  end
  return fallback
end

local function format_pct(percent, reset, used)
  if percent == nil and used == nil then
    return "—"
  end
  -- Prefer remaining; if over-limit (used > 100) show used so we never print "-30%".
  local show = percent
  local suffix = ""
  if used ~= nil and used > 100 then
    show = used
    suffix = " used"
  elseif show == nil then
    show = used
  end
  local text = string.format("%3.0f%%%s", show, suffix)
  local r = short_reset(reset)
  if r then
    text = text .. "  " .. r
  end
  return text
end

local function max_pct(...)
  local best = nil
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v ~= nil and (best == nil or v > best) then
      best = v
    end
  end
  return best
end

local function set_capsule(session_used, weekly_used, fable_used, grok_used, err)
  if err then
    ccu:set {
      background = ui.capsule(),
      label = { string = "CCu ?", color = theme.critical },
    }
    return
  end

  local pct = max_pct(session_used, weekly_used, fable_used, grok_used)
  if pct == nil then
    ccu:set {
      background = ui.capsule(),
      label = { string = "CCu", color = theme.text_muted },
    }
    return
  end

  ccu:set {
    background = ui.capsule(),
    label = {
      string = string.format("CCu %.0f%%", pct),
      color = usage_color(pct),
    },
  }
end

local function apply_window_row(row, accent, win, title_fallback)
  if not win then
    row:set {
      icon = { string = title_fallback, color = accent },
      label = { string = "—", color = theme.text_muted },
    }
    set_percent(row, accent, 0)
    return nil
  end
  row:set {
    icon = { string = row_title(win, title_fallback), color = accent },
    label = {
      string = format_remaining(win),
      color = usage_color(win.used),
    },
  }
  -- Bar shows remaining (CLI progress bar style).
  set_percent(row, accent, win.remaining)
  return win.used
end

local function apply_claude(result)
  if result.error then
    -- Keep last-good rows on transient failures (429 / parse / network).
    local had = last.session ~= nil or last.weekly ~= nil or last.fable ~= nil
    if not had then
      session_row:set {
        icon = { string = "Session (5h)", color = accent_session },
        label = { string = result.error, color = theme.critical },
      }
      weekly_row:set {
        icon = { string = "Week (7d)", color = accent_weekly },
        label = { string = "—", color = theme.text_muted },
      }
      fable_row:set {
        icon = { string = "Weekly Fable", color = accent_fable },
        label = { string = "—", color = theme.text_muted },
      }
      set_percent(session_row, accent_session, 0)
      set_percent(weekly_row, accent_weekly, 0)
      set_percent(fable_row, accent_fable, 0)
    end
  else
    last.session = apply_window_row(session_row, accent_session, result.session, "Session (5h)")
    last.weekly = apply_window_row(weekly_row, accent_weekly, result.weekly, "Week (7d)")
    last.fable = apply_window_row(fable_row, accent_fable, result.scoped, "Weekly Fable")
  end
  set_capsule(last.session, last.weekly, last.fable, last.grok, result.error and not last.grok and not last.session)
end

local function apply_grok(result)
  if result.error then
    if last.grok == nil then
      grok_row:set { label = { string = result.error, color = theme.critical } }
      set_percent(grok_row, accent_grok, 0)
    end
  else
    local used = result.utilization
    local remaining = result.remaining
    if remaining == nil and used ~= nil then
      remaining = math.max(0, 100 - used)
    end
    last.grok = used
    grok_row:set {
      label = {
        string = format_pct(remaining, result.resets_at, used),
        color = usage_color(used),
      },
    }
    -- Bar = remaining (CLI style); over-limit → 0%.
    set_percent(grok_row, accent_grok, remaining or 0)
  end
  set_capsule(last.session, last.weekly, last.fable, last.grok, result.error and not last.session and not last.grok)
end

local function refresh_theme()
  accent_session = colors.mauve
  accent_weekly = colors.blue
  accent_fable = colors.pink
  accent_grok = colors.teal
  ccu:set { popup = { background = ui.popup() } }
  session_row:set { icon = { color = accent_session }, label = { color = usage_color(last.session) } }
  weekly_row:set { icon = { color = accent_weekly }, label = { color = usage_color(last.weekly) } }
  fable_row:set { icon = { color = accent_fable }, label = { color = usage_color(last.fable) } }
  grok_row:set { icon = { color = accent_grok }, label = { color = usage_color(last.grok) } }
  for _, btn in ipairs { claude_link, grok_link } do
    btn:set {
      label = { color = theme.text_muted },
      background = ui.button { height = row_h },
    }
  end
  -- Bars: remaining for Claude (stored used in last.*); invert for display.
  set_percent(session_row, accent_session, last.session and (100 - last.session) or 0)
  set_percent(weekly_row, accent_weekly, last.weekly and (100 - last.weekly) or 0)
  set_percent(fable_row, accent_fable, last.fable and (100 - last.fable) or 0)
  set_percent(grok_row, accent_grok, last.grok and (100 - last.grok) or 0)
  set_capsule(last.session, last.weekly, last.fable, last.grok)
end

ccu:subscribe("theme_colors_updated", refresh_theme)
refresh_theme()

local function refresh_usage()
  get_claude_usage(apply_claude)
  get_grok_usage(apply_grok)
end

-- Always refresh capsule (was stuck after first failed fetch when popup closed).
-- Open popup: 20s; closed: 60s — avoids Claude 429 from 10s hammering.
local refresh_timer = sbar.add("item", "widgets.ccu.refresh_timer", {
  update_freq = 60,
  drawing = false,
})

refresh_timer:subscribe("routine", function()
  local open = ccu:query().popup.drawing == "on"
  refresh_timer:set { update_freq = open and 20 or 60 }
  refresh_usage()
end)

ui.bind_popup(ccu, { on_open = refresh_usage })
refresh_usage()
