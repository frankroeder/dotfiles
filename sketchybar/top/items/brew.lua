local colors = require("colors")
local icons = require("icons")

local brew = sbar.add("item", "widgets.brew", {
  position = "right",
  icon = {
    string = icons.brew,
    color = colors.white,
  },
  label = {
    string = "?",
  },
  update_freq = 3600,
})

local function update_brew()
  sbar.exec("unset RUBYOPT; unset RUBYLIB; PATH='/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' HOMEBREW_NO_AUTO_UPDATE=1 brew outdated 2>/dev/null | wc -l", function(count)
    local outdated = tonumber(count:match("%d+")) or 0
    brew:set({
      label = { string = tostring(outdated) },
      drawing = outdated > 0,
    })
  end)
end

brew:subscribe({"routine", "system_woke"}, update_brew)
update_brew()