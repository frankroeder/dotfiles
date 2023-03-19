require "options"
require "keymaps"
require "plugin_manager"
require "autocommands"

local local_vimrc = os.getenv "HOME" .. "/.local.vim"
if vim.fn.filereadable(local_vimrc) then
  vim.cmd("source " .. local_vimrc)
end
