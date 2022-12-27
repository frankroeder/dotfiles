local M = {
  "plasticboy/vim-markdown",
  dependencies = { "godlygeek/tabular" },
}

function M.config()
  vim.cmd [[
	let g:vim_markdown_folding_disabled = 1
	let g:vim_markdown_new_list_item_indent = 0
	let g:vim_markdown_fenced_languages = ['html', 'css', 'js=javascript',
				\ 'c++=cpp', 'c', 'go', 'viml=vim', 'bash=sh', 'python']
	let g:vim_markdown_strikethrough = 1

	augroup markdown
		au Filetype markdown nmap <buffer> <Space>tt :Toc <CR>
		au Filetype markdown nmap <buffer> <Space>hi :HeaderIncrease <CR>
		au Filetype markdown nmap <buffer> <Space>hd :HeaderDecrease <CR>
		au Filetype markdown nmap <buffer> <Space>tf :TableFormat <CR>
	augroup END
	]]
end

return M
