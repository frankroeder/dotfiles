require('lualine').setup {
	options = {
		globalstatus = true,
		theme = "catppuccin",
		disabled_filetypes = {'help'}
	},
	extensions = {'nvim-tree', 'fzf'},
}
