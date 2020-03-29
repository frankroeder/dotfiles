set conceallevel=2
let g:tex_conceal ='abdmg'
let g:tex_flavor = "latex"
let g:vimtex_view_method='skim'
let g:vimtex_view_general_viewer
      \ = '/Applications/Skim.app/Contents/SharedSupport/displayline'
let g:vimtex_view_general_options = '-r @line @pdf @tex'
let g:vimtex_quickfix_mode=0
let g:vimtex_compiler_latexmk = {'callback' : 0}
let g:vimtex_compiler_enabled = 0
let g:vimtex_toc_config = {
      \ 'split_pos': 'full',
      \ 'layer_status': {'label': 0}
      \}

augroup tex
  au FileType tex nmap <F2> :VimtexTocOpen <CR>
  au FileType tex nmap <F3> :VimtexInfo <CR>
  au FileType tex nmap <F4> :VimtexErrors <CR>
  au FileType tex nmap gd :VimtexDocPackage <CR>
augroup END

if has('nvim')
  let g:vimtex_compiler_progname = 'nvr'
endif
