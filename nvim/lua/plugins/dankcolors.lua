return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#1a110f',
				base01 = '#1a110f',
				base02 = '#a59c99',
				base03 = '#a59c99',
				base04 = '#fff3ef',
				base05 = '#fffaf8',
				base06 = '#fffaf8',
				base07 = '#fffaf8',
				base08 = '#ffa19f',
				base09 = '#ffa19f',
				base0A = '#ffc0ae',
				base0B = '#b7ffa5',
				base0C = '#ffddd4',
				base0D = '#ffc0ae',
				base0E = '#ffcbbc',
				base0F = '#ffcbbc',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#a59c99',
				fg = '#fffaf8',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#ffc0ae',
				fg = '#1a110f',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#a59c99' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#ffddd4', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#ffcbbc',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#ffc0ae',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#ffc0ae',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#ffddd4',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#b7ffa5',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#fff3ef' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#fff3ef' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#a59c99',
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
