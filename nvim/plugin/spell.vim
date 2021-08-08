" Spell error: pick the first result
nnoremap <Leader>z z=1<CR><CR>

" Fix spelling mistakes on the fly
inoremap <C-S> <C-G>u<Esc>[s1z=`]a<C-G>u

" Toggle between languages
let g:myLang=0
let g:myLangList=["nospell","en","de"]

function! ToggleSpell()
  let g:myLang=g:myLang+1
  if g:myLang>=len(g:myLangList) | let g:myLang=0 | endif
  if g:myLang==0
    setlocal nospell
  else
    execute "setlocal spell spelllang=".get(g:myLangList, g:myLang)
  endif
  echo "spell checking language:" g:myLangList[g:myLang]
endfunction

nmap <silent> <Space>ts :call ToggleSpell()<CR>
