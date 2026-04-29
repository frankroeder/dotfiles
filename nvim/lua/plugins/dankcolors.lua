return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#121314',
				base01 = '#121314',
				base02 = '#7c8386',
				base03 = '#7c8386',
				base04 = '#ccd5d9',
				base05 = '#f8fdff',
				base06 = '#f8fdff',
				base07 = '#f8fdff',
				base08 = '#ff9fbe',
				base09 = '#ff9fbe',
				base0A = '#cfdee3',
				base0B = '#a1f8aa',
				base0C = '#f2fbff',
				base0D = '#cfdee3',
				base0E = '#ecf9ff',
				base0F = '#ecf9ff',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#7c8386',
				fg = '#f8fdff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#cfdee3',
				fg = '#121314',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#7c8386' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#f2fbff', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#ecf9ff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#cfdee3',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#cfdee3',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#f2fbff',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#a1f8aa',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#ccd5d9' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#ccd5d9' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#7c8386',
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
