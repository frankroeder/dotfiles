if vim.fn.has('termguicolors') then
	vim.fn.setenv('NVIM_TUI_ENABLE_TRUE_COLOR', 1)
	vim.opt.termguicolors = true
end

local catppuccin = require("catppuccin")

catppuccin.setup({
	-- general
	transparent_background = true,
	term_colors = false,
	styles = {
		comments = { "italic" },
		conditionals = { "italic" },
		loops = {},
		functions = {},
		keywords = {},
		strings = {},
		variables = { "italic" },
		numbers = {},
		booleans = {},
		properties = {},
		types = {},
		operators = {},
	},
	integrations = {
		treesitter = true,
		native_lsp = {
			enabled = true,
			virtual_text = {
				errors = { "italic" },
				hints = { "italic" },
				warnings = { "italic" },
				information = { "italic" },
			},
			underlines = {
				errors = { "underline" },
				hints = { "underline" },
				warnings = { "underline" },
				information = { "underline" },
			},
		},
		lsp_trouble = false,
		cmp = true,
		lsp_saga = false,
		gitgutter = false,
		gitsigns = true,
		telescope = false,
		nvimtree = {
			enabled = true,
			show_root = false,
			transparent_panel = false,
		},
		neotree = {
			enabled = false,
			show_root = false,
			transparent_panel = false,
		},
		which_key = true,
		indent_blankline = {
			enabled = true,
			colored_indent_levels = false,
		},
		dashboard = false,
		neogit = false,
		vim_sneak = false,
		fern = false,
		barbar = true,
		bufferline = false,
		markdown = true,
		lightspeed = false,
		ts_rainbow = true,
		hop = false,
		notify = false,
		telekasten = false,
		symbols_outline = true,
	}
})
vim.g.catppuccin_flavour = "mocha" -- latte, frappe, macchiato, mocha
vim.cmd[[colorscheme catppuccin]]
