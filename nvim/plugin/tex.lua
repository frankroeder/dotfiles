local keymap = require("utils").keymap

vim.wo.conceallevel = 0
vim.g.tex_conceal = "abdmg"
vim.g.tex_flavor = "latex"
vim.g.vimtex_view_method = "sioyek"
vim.g.vimtex_view_general_options = "-r @line @pdf @tex"
vim.g.vimtex_quickfix_mode = 0
vim.g.vimtex_complete_close_braces = 1
vim.g.vimtex_view_automatic = 0

vim.cmd [[
	function! Callback(msg)
	let l:m = matchlist(a:msg, '\vRun number (\d+) of rule ''(.*)''')
	if !empty(l:m)
	echomsg l:m[2] . ' (' . l:m[1] . ')'
	endif
	endfunction
	]]

vim.g.vimtex_compiler_latexmk = {
  backend = "nvim",
  background = 1,
  build_dir = "build/",
  callback = 1,
  continuous = 1,
  executable = "latexmk",
  hooks = {
    Callback,
  },
  options = {
    "-verbose",
    "-file-line-error",
    "-synctex=1",
    "-interaction=nonstopmode",
  },
}

vim.g.vimtex_toc_config = {
  split_pos = "full",
  layer_status = {
    label = 0,
  },
}

vim.g.vimtex_complete_bib = {
  simple = 0,
  menu_fmt = '@key @author_short (@year), "@title"',
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function()
    keymap("n", "<Space>tt", "<plug>(vimtex-toc-toggle)", {})
    keymap("n", "<Space>tv", "<plug>(vimtex-view)", {})
    keymap("n", "<Space>tc", "<plug>(vimtex-compile)", {})
    keymap(
      "n",
      "<C-F>*",
      [[:call vimtex#fzf#run('cti', {'window': { 'width': 0.6, 'height': 0.6 } })<CR>]],
      {}
    )
  end,
  desc = "VimTex key mappings",
})

vim.cmd [[
function! ShowTexDoc(context)
	call vimtex#doc#make_selection(a:context)
	if !empty(a:context.selected)
		execute '!texdoc' a:context.selected '&'
	endif
	return 1
endfunction
]]
vim.g.vimtex_doc_handlers = { "ShowTexDoc" }
