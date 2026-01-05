local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local hackernews = sbar.add("item", "widgets.hackernews", {
  position = "right",
  update_freq = 600, -- 10 minutes
  icon = {
    string = icons.hackernews,
    color = colors.orange,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "Loading...",
    font = {
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
    padding_right = 8,
    color = colors.white,
    max_chars = 40,
    scroll_duration = 100,
  },
})

local hn_popup = sbar.add("item", {
  position = "popup." .. hackernews.name,
  label = {
    font = { size = 12.0 },
    max_chars = 60,
    string = "Loading top stories..."
  },
  background = {
    color = colors.bg1,
    border_color = colors.black,
    border_width = 1,
    corner_radius = 5,
  }
})

local function update_hn()
  sbar.exec([[
    IDS=$(curl -s "https://hacker-news.firebaseio.com/v0/topstories.json" | grep -oE "[0-9]+" | head -n 5)
    for id in $IDS; do
      curl -s "https://hacker-news.firebaseio.com/v0/item/$id.json" | jq -r ".title"
    done
  ]], function(titles)
    if titles and titles ~= "" then
      local first_title = titles:match("[^\n]+")
      hackernews:set({ label = { string = first_title } })
      
      local popup_content = ""
      for title in titles:gmatch("[^\n]+") do
        popup_content = popup_content .. "• " .. title .. "\n"
      end
      hn_popup:set({ label = { string = popup_content } })
    end
  end)
end

hackernews:subscribe({"routine", "system_woke", "forced"}, update_hn)

hackernews:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec("open 'https://news.ycombinator.com'")
  else
    hackernews:set({ popup = { drawing = "toggle" } })
  end
end)

