local settings = require("settings")

if settings.theme == "onedark" then
  return {
    "joshdick/onedark.vim",
		lazy = false,
    config = function()
      require("plugins.themes.nightfox")
    end,
  }
else
  return {
    "catppuccin/nvim",
    name = "catppuccin",
		lazy = false,
    config = function()
      require("plugins.themes.catppuccin")
    end,
  }
end
