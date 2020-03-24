let g:LanguageClient_serverCommands = {
      \ 'python': ['/usr/local/bin/pyls'],
      \ 'javascript': ['typescript-language-server', '--stdio'],
      \ 'typescript': ['typescript-language-server', '--stdio'],
      \ 'c': ['clangd'],
      \ 'cpp': ['clangd'],
      \ 'go': ['gopls'],
      \ 'swift': ['sourcekit-lsp'],
      \ 'sh': ['bash-language-server', 'start'],
      \ 'zsh': ['bash-language-server', 'start'],
      \ }

let g:LanguageClient_diagnosticsEnable = 0
let g:LanguageClient_diagnosticsList = "Disabled"
let g:LanguageClient_loggingFile = '/tmp/LanguageClient.log'
let g:LanguageClient_serverStderr = '/tmp/LanguageServer.log'
let g:LanguageClient_settingsPath = expand('~/.config/nvim/settings.json')

let g:LanguageClient_rootMarkers = [ '.root', 'project.*', '.git/','.gitignore',
      \'README.md', 'venv/', '.vim/', 'requirements.txt', 'package.json']

let g:LanguageClient_fzfOptions = $FZF_DEFAULT_OPTS
let g:LanguageClient_hasSnippetSupport = 1

function LC_maps()
  if has_key(g:LanguageClient_serverCommands, &filetype)
    nnoremap <F2> :call LanguageClient_contextMenu()<CR>
    nnoremap <F3> :call LanguageClient#textDocument_references()<CR>
    nnoremap <silent> K :call LanguageClient#textDocument_hover()<CR>
    nnoremap <silent> gd :call LanguageClient#textDocument_definition()<CR>
    nnoremap <silent> <Leader>rn :call LanguageClient#textDocument_rename()<CR>
  endif
endfunction

autocmd FileType * call LC_maps()
