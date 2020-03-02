" coc
hi! CocErrorSign  ctermfg=Red guifg=#e06c75
hi! CocWarningSign  ctermfg=Brown guifg=#e5c07b
hi! CocInfoSign  ctermfg=Yellow guifg=#abb2bf

let g:coc_global_extensions = [
      \'coc-tsserver', 'coc-python','coc-css', 'coc-snippets', 'coc-json',
      \'coc-html', 'coc-vimtex'
      \]

inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()

inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

inoremap <silent><expr> <C-space> coc#refresh()

inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" Close the preview window when completion is done.
autocmd! CompleteDone * if pumvisible() == 0 | pclose | endif

" Use <tab> for select selections ranges, needs server
" support, like: coc-tsserver, coc-python
nmap <silent> <TAB> <Plug>(coc-range-select)
xmap <silent> <TAB> <Plug>(coc-range-select)
xmap <silent> <S-TAB> <Plug>(coc-range-select-backword)

nmap <silent> <F2> <Plug>(coc-implementation)
nmap <silent> <F3> <Plug>(coc-type-definition)
nmap <silent> <F4> <Plug>(coc-references)
nmap <silent> gd <Plug>(coc-definition)

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Highlight symbol under cursor on CursorHold
autocmd CursorHold * silent call CocActionAsync('highlight')

nmap <silent> gn <Plug>(coc-diagnostic-next)
nmap <silent> gp <Plug>(coc-diagnostic-prev)
nmap <silent> <Leader>rn <Plug>(coc-rename)
nmap <silent> <Leader>rf :call CocAction('runCommand', 'workspace.renameCurrentFile')<CR>
nmap <silent> <Leader>d :<C-u>CocList diagnostics<CR>
nmap <silent> <Leader>i :<C-u>CocInfo<CR>
nmap <silent> <F12> <Plug>(coc-format)

xmap <leader>f <Plug>(coc-format-selected)
nmap <leader>f <Plug>(coc-format-selected)

command! -nargs=? Fold :call CocAction('fold', <f-args>)
command! -nargs=0 OR :call CocAction('runCommand', 'editor.action.organizeImport')

au FileType python nmap <silent> <Leader>l :call CocAction('runCommand', 'python.runLinting')<CR>
au FileType python nmap <silent> <Leader>ll :call CocAction('runCommand', 'python.enableLinting')<CR>
