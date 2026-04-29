return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#161311',
				base01 = '#161311',
				base02 = '#908985',
				base03 = '#908985',
				base04 = '#e9e0db',
				base05 = '#fffaf8',
				base06 = '#fffaf8',
				base07 = '#fffaf8',
				base08 = '#ffa39f',
				base09 = '#ffa39f',
				base0A = '#f4d9ca',
				base0B = '#b6ffa5',
				base0C = '#fff0e7',
				base0D = '#f4d9ca',
				base0E = '#ffe7da',
				base0F = '#ffe7da',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#908985',
				fg = '#fffaf8',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#f4d9ca',
				fg = '#161311',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#908985' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#fff0e7', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#ffe7da',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#f4d9ca',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#f4d9ca',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#fff0e7',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#b6ffa5',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#e9e0db' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#e9e0db' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#908985',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
