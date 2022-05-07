local keymap  = require 'utils'.keymap

vim.g.NERDSpaceDelims = 1
vim.g.NERDCompactSexyComs = 1
vim.g.NERDDefaultAlign = 'left'
vim.g.NERDCustomDelimiters = {
	c = { left = [[/**]], right = [[*/]] }
}
vim.g.NERDCommentEmptyLines = 1
vim.g.NERDTrimTrailingWhitespace = 1

keymap("n", "<Leader>cc", [[NERDComComment]])
keymap("n", "<Leader>c<Space>", [[NERDComToggleComment]])
keymap("n", "<Leader>cs", [[NERDComSexyComment]])
