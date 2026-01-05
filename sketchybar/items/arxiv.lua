local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local arxiv = sbar.add("item", "widgets.arxiv", {
  position = "right",
  update_freq = 3600, -- 1 hour
  icon = {
    string = icons.arxiv,
    color = colors.blue,
    padding_left = 8,
    font = {
      style = "Regular",
      size = 16.0,
    },
  },
  label = {
    string = "Latest ML Paper...",
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

local function update_arxiv()
  sbar.exec([[
    curl -s "http://export.arxiv.org/api/query?search_query=cat:cs.LG&sortBy=submittedDate&sortOrder=descending&max_results=1" | \
    grep -oE "<title>[^<]+" | \
    sed 's/<title>//' | \
    tail -n 1
  ]], function(title)
    if title and title ~= "" then
      arxiv:set({
        label = { string = title:gsub("\n", "") },
      })
    end
  end)
end

arxiv:subscribe({"routine", "system_woke", "forced"}, update_arxiv)

arxiv:subscribe("mouse.clicked", function()
  sbar.exec("open 'https://arxiv.org/list/cs.LG/recent'")
end)

