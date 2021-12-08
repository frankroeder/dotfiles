augroup CustomAutoCmds
  autocmd!

  " trim whitespaces
  autocmd BufWritePre * :call StripTrailingWhitespaces()

  " toggle line numbers
  autocmd FocusGained,InsertLeave * set relativenumber
  autocmd FocusLost,InsertEnter   * set norelativenumber

  " toggle color of column
  autocmd BufEnter,FocusGained,InsertLeave * set cc=
  autocmd BufLeave,FocusLost,InsertEnter   * set cc=81

  " auto read
  autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif
  autocmd FileChangedShellPost *
        \ echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None

  " highlight yanks
  if has('nvim')
    autocmd TextYankPost *
          \ silent! lua return (not vim.v.event.visual)
          \   and vim.highlight.on_yank {higroup='IncSearch', timeout=300}
  endif
  autocmd BufWritePost *.snippets :CmpUltisnipsReloadSnippets
augroup END
