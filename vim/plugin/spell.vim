" Spell error: pick the first result
nnoremap <Leader>z z=1<CR><CR>

" Fix spelling mistakes on the fly
inoremap <C-S> <C-G>u<Esc>[s1z=`]a<C-G>u

" Toggle between languages
let b:myLang=0
let g:myLangList=["nospell","de","en"]
function! ToggleSpell()
  let b:myLang=b:myLang+1
  if b:myLang>=len(g:myLangList) | let b:myLang=0 | endif
  if b:myLang==0
    setlocal nospell
  else
    execute "setlocal spell spelllang=".get(g:myLangList, b:myLang)
  endif
  echo "spell checking language:" g:myLangList[b:myLang]
endfunction

nmap <silent> <F6> :call ToggleSpell()<CR>
