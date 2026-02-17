local colors = require "colors"
local settings = require "settings"

local claude = sbar.add("item", "widgets.claude", {
  position = "left",
  update_freq = 900,
  icon = {
    string = ":claude:",
    color = colors.white,
    padding_left = 8,
    padding_right = 4,
    font = "sketchybar-app-font:Regular:16.0",
  },
  label = {
    string = "...",
    color = colors.white,
    padding_left = 0,
    padding_right = 8,
    font = {
      style = settings.font.style_map["Regular"],
      size = 12.0,
    },
  },
})

local function update_quota()
  sbar.exec(
    "$HOME/bin/claude-quota --json | jq -r '[.session.percentRemaining, .weekly.percentRemaining, .weeklySonnet.percentRemaining, .session.resetText] | join(\"|\")'",
    function(result)
      local values = result:gsub("%s+", "")

      if values == "" or values:match "null" then
        claude:set { label = { string = "N/A", color = colors.grey } }
        return
      end

      local session, weekly, sonnet, reset = values:match "([^|]+)|([^|]+)|([^|]+)|([^|]+)"
      local s_pct = tonumber(session)
      local w_pct = tonumber(weekly)
      local sn_pct = tonumber(sonnet)

      if not s_pct or not w_pct or not sn_pct then
        claude:set { label = { string = "N/A", color = colors.grey } }
        return
      end

      local min_pct = math.min(s_pct, w_pct, sn_pct)
      local color = colors.green
      if min_pct < 20 then
        color = colors.red
      elseif min_pct < 50 then
        color = colors.yellow
      end

      local label_text = s_pct .. "|" .. w_pct .. "|" .. sn_pct
      if reset and reset ~= "" then
        label_text = label_text .. " (" .. reset .. ")"
      end

      claude:set {
        label = {
          string = label_text,
          color = color,
        },
      }
    end
  )
end

claude:subscribe({ "routine", "forced", "system_woke" }, update_quota)

update_quota()
