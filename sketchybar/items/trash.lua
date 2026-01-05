local colors = require("colors")

local trash = sbar.add("item", "widgets.trash", {
  position = "right",
  icon = {
    string = "􀈸",
    color = colors.grey,
    padding_left = 8,
    font = {
        style = "Regular",
        size = 16.0,
    },
  },
  label = {
    string = "?",
    color = colors.white,
    padding_right = 8,
  },
  update_freq = 600,
})

trash:subscribe({ "routine", "forced", "system_woke" }, function()
  sbar.exec("du -sh ~/.Trash | awk '{print $1}'", function(size)
    local trash_size = size:gsub("%s+", "")
    if trash_size ~= "0B" and trash_size ~= "" then
      trash:set({
        label = { string = trash_size },
        drawing = true,
      })
    else
      trash:set({ drawing = false })
    end
  end)
end)

trash:subscribe("mouse.clicked", function()
  sbar.exec("~/.dotfiles/bin/Darwin/emptytrash")
  sbar.delay(1, function() sbar.trigger("forced") end)
end)
