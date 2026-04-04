pcall(vim.loader.enable)

require "options"
require "keymaps"
require "autocommands"
vim.cmd.packadd "nvim.undotree"

local localnvim = os.getenv "HOME" .. "/.localnvim.lua"
if vim.fn.filereadable(localnvim) then
  vim.cmd("source " .. localnvim)
end
