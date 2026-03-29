return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#101418',
				base01 = '#101418',
				base02 = '#aaaeb2',
				base03 = '#aaaeb2',
				base04 = '#36383a',
				base05 = '#f6faff',
				base06 = '#f6faff',
				base07 = '#f6faff',
				base08 = '#fb1e60',
				base09 = '#fb1e60',
				base0A = '#077df1',
				base0B = '#07e724',
				base0C = '#8ec7ff',
				base0D = '#077df1',
				base0E = '#b7dbff',
				base0F = '#b7dbff',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#aaaeb2',
				fg = '#f6faff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#077df1',
				fg = '#101418',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#aaaeb2' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#8ec7ff', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#b7dbff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#077df1',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#077df1',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#8ec7ff',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#07e724',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#36383a' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#36383a' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#aaaeb2',
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
