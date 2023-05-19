local settings = require("settings")

if settings.theme == "onedark" then
  return {
    "joshdick/onedark.vim",
		lazy = false,
    priority = 1000,
    config = function()
      require("plugins.themes.onedark")
    end,
  }
else
  return {
    "catppuccin/nvim",
    name = "catppuccin",
		lazy = false,
    priority = 1000,
    config = function()
      require("plugins.themes.catppuccin")
    end,
  }
end
