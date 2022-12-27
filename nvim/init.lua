-- vim.cmd("highlight MatchParen gui=bold,reverse guifg=#413e3d guibg=#f9d39e")

require "options"
require "keymaps"
require "plugin_manager"
require "autocommands"
require "neovide"

-- make tsutils globally available for legacy vim
Tsutils = require "tsutils"

local local_vimrc = os.getenv "HOME" .. "/.local.vim"
if vim.fn.filereadable(local_vimrc) then
  vim.cmd("source " .. local_vimrc)
end
