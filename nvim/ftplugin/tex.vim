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

" nnoremap <C-p> :call LatexClipboardImage()<CR>

function! LatexClipboardImage() abort
  " Create `img` directory if it doesn't exist
  let img_dir = getcwd() . '/imgs'
  if !isdirectory(img_dir)
    silent call mkdir(img_dir)
  endif

  " First find out what filename to use
  let index = 1
  let file_path = img_dir . "/image" . index . ".png"
  while filereadable(file_path)
    let index = index + 1
    let file_path = img_dir . "/image" . index . ".png"
  endwhile

  let clip_command = 'osascript'
  let clip_command .= ' -e "set png_data to the clipboard as «class PNGf»"'
  let clip_command .= ' -e "set referenceNumber to open for access POSIX path of'
  let clip_command .= ' (POSIX file \"' . file_path . '\") with write permission"'
  let clip_command .= ' -e "write png_data to referenceNumber"'

  silent call system(clip_command)
  if v:shell_error == 1
    normal! p
    echoerr "Error: Missing Image in Clipboard"
  else
    let caption = getline('.')
    execute "normal!".
    \"i"
    \"\\includegraphics[width=200px]{./imgs/image" . index . ".png}\r"
    execute "normal! k4w:w"
  endif
endfunction
