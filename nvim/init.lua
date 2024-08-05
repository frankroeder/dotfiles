require "options"
require "keymaps"
require "plugin_manager"
require "autocommands"

local localnvim = os.getenv "HOME" .. "/.localnvim.lua"
if vim.fn.filereadable(localnvim) then
  vim.cmd("source " .. localnvim)
end
