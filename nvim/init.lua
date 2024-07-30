require "options"
require "keymaps"
require "plugin_manager"
require "autocommands"
local settings = require "settings"
vim.cmd("colorscheme " .. settings.theme)

local localnvim = os.getenv "HOME" .. "/.localnvim.lua"
if vim.fn.filereadable(localnvim) then
  vim.cmd("source " .. localnvim)
end
