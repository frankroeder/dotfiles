setl iskeyword+=:,-
setl indentexpr=
setl wrap
setl linebreak

" Automatically add \item https://stackoverflow.com/a/42389579
function! AddItem()
  let [end_lnum, end_col] = searchpairpos('\\begin{', '', '\\end{', 'nW')
  if match(getline(end_lnum), '\(itemize\|enumerate\|description\)') != -1
    return "\\item "
  else
    return ""
  endif
endfunction
inoremap <expr><buffer> <CR> getline('.') =~ '\item $'
  \ ? '<c-w><c-w>'
  \ : (col(".") < col("$") ? '<CR>' : '<CR>'.AddItem() )
nnoremap <expr><buffer> o "o".AddItem()
nnoremap <expr><buffer> O "O".AddItem()
