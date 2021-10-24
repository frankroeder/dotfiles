set conceallevel=0
let g:tex_conceal ='abdmg'
let g:tex_flavor = "latex"

let g:vimtex_view_method ='skim'
let g:vimtex_view_general_viewer
      \ = '/Applications/Skim.app/Contents/SharedSupport/displayline'
let g:vimtex_view_general_options = '-r @line @pdf @tex'
let g:vimtex_quickfix_mode = 0
let g:vimtex_complete_close_braces = 1
let g:vimtex_view_automatic = 0

function! Callback(msg)
  let l:m = matchlist(a:msg, '\vRun number (\d+) of rule ''(.*)''')
  if !empty(l:m)
    echomsg l:m[2] . ' (' . l:m[1] . ')'
  endif
endfunction

let g:vimtex_compiler_latexmk = {
    \ 'backend' : 'nvim',
    \ 'background' : 1,
    \ 'build_dir' : 'build/',
    \ 'callback' : 1,
    \ 'continuous' : 1,
    \ 'executable' : 'latexmk',
    \ 'hooks' : [function('Callback')],
    \ 'options' : [
    \   '-lualatex',
    \   '-verbose',
    \   '-file-line-error',
    \   '-synctex=1',
    \   '-interaction=nonstopmode',
    \ ],
    \}

let g:vimtex_toc_config = {
      \ 'split_pos': 'full',
      \ 'layer_status': {'label': 0}
      \}

let g:vimtex_complete_bib ={
      \ 'simple' : 0,
      \ 'menu_fmt': '@key @author_short (@year), "@title"'
      \}

augroup tex
  au FileType tex nmap <buffer> <Space>tt <plug>(vimtex-toc-toggle)
  au FileType tex nmap <buffer> <Space>tv <plug>(vimtex-view)
  au FileType tex nmap <buffer> <Space>tc <plug>(vimtex-compile)
  au Filetype tex nmap <silent> <buffer> <C-F> :call vimtex#fzf#run('cti', {'window': { 'width': 0.6, 'height': 0.6 } })<CR>
  " additional sources added to the global ones
  autocmd FileType tex lua require'cmp'.setup.buffer {
        \   sources = {
        \     { name = 'omni' },
        \ }

augroup END

let g:vimtex_doc_handlers = ['ShowTexDoc']

function! ShowTexDoc(context)
  call vimtex#doc#make_selection(a:context)
  if !empty(a:context.selected)
    execute '!texdoc' a:context.selected '&'
  endif
  return 1
endfunction
