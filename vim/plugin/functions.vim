function StripTrailingWhitespaces()
  " last cursor and search position
  let _s=@/
  let l = line(".")
  let c = col(".")
  %s/\s\+$//e
  let @/=_s
  call cursor(l, c)
endfunction

function! ToggleConcealLevel()
  if &conceallevel == 0
    setlocal conceallevel=1
  elseif &conceallevel == 1
    setlocal conceallevel=2
  elseif &conceallevel == 2
    setlocal conceallevel=0
  endif
  echo "Conceal level" &conceallevel
endfunction

nnoremap <silent><Leader>tc :call ToggleConcealLevel()<CR>
