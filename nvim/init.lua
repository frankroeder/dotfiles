-- vim.cmd("highlight MatchParen gui=bold,reverse guifg=#413e3d guibg=#f9d39e")

require "options"
require "keymaps"
require "plugins"
require "autocommands"
require "neovide"

-- make tsutils available for legacy vim
tsutils = require "tsutils"

local local_vimrc = os.getenv "HOME" .. "/.local.vim"
if vim.fn.filereadable(local_vimrc) then
  vim.cmd("source " .. local_vimrc)
end
