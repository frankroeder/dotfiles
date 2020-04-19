" From https://github.com/farmergreg/vim-lastplace

let g:last_position_ignore = "gitcommit,gitrebase,svn,hgcommit"
let g:last_position_ignore_buftype = "quickfix,nofile,help"

function! s:LastPostion()

  if index(split(g:last_position_ignore_buftype, ","), &buftype) != -1
    return
  endif

  if index(split(g:last_position_ignore, ","), &filetype) != -1
    return
  endif

  try
    "if the file does not exist on disk then do nothing
    if empty(glob(@%))
      return
    endif
  catch
    return
  endtry
  if line("'\"") > 0 && line("'\"") <= line("$")
    "if the last edit position is set and is less than the
    "number of lines in this buffer.

    if line("w$") == line("$")
      "if the last line in the current buffer is
      "also the last line visible in this window
      execute "normal! g`\""

    elseif line("$") - line("'\"") > ((line("w$") - line("w0")) / 2) - 1
      "if we're not at the bottom of the file, center the
      "cursor on the screen after we make the jump
      execute "normal! g`\"zz"

    else
      "otherwise, show as much context as we can by jumping
      "to the end of the file and then to the mark. If we
      "pressed zz here, there would be blank lines at the
      "bottom of the screen. We intentionally leave the
      "last line blank by pressing <c-e> so the user has a
      "clue that they are near the end of the file.
      execute "normal! \G'\"\<c-e>"
    endif
  endif
endfunction

" Return to last edit position when opening files
augroup resume_edit_position
  autocmd!
  autocmd BufWinEnter * call s:LastPostion()
augroup END
