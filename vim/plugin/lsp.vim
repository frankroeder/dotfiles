let s:py_lsp = ['/usr/local/bin/pyls', '--log-file', '/tmp/pyls.log']
let s:js_ts_lsp =  ['/usr/local/bin/javascript-typescript-stdio', '-l', '/tmp/js_ts.log']
let s:c_cpp_lsp = ['/usr/local/opt/llvm/bin/clangd', '--clang-tidy', '--suggest-missing-includes']
let s:go_lsp = [$GOPATH.'/bin/gopls', '-logfile', '/tmp/gopls.log']
let s:swift_lsp = ['/usr/local/sourcekit-lsp']
let s:html_lsp = ['html-languageserver', '--stdio']
let s:css_lsp = ['css-languageserver', '--stdio']

let g:LanguageClient_serverCommands = {
      \ 'python': s:py_lsp,
      \ 'javascript': s:js_ts_lsp,
      \ 'typescript': s:js_ts_lsp,
      \ 'c': s:c_cpp_lsp,
      \ 'cpp': s:c_cpp_lsp,
      \ 'go': s:go_lsp,
      \ 'swift': s:swift_lsp,
      \ 'html': s:html_lsp,
      \ 'css': s:css_lsp,
      \ }

let g:LanguageClient_diagnosticsEnable = 0
let g:LanguageClient_diagnosticsList = "Disabled"
let g:LanguageClient_useVirtualText = 'No'
let g:LanguageClient_loggingLevel = 'ERROR'
let g:LanguageClient_loggingFile = '/tmp/LanguageClient.log'
let g:LanguageClient_serverStderr = '/tmp/LanguageServer.log'
let g:LanguageClient_settingsPath = expand('~/.config/nvim/settings.json')
let g:LanguageClient_loadSettings = 1

let s:general_rm = ['.root', 'project.*', '.git/','.gitignore', 'README.md',
      \'.vim/', 'LICENSE']
let s:py_rm =  ['venv/', 'requirements.txt', 'setup.py']
let s:js_ts_rm = ['jsconfig.json', 'tsconfig.json', 'package.json']
let s:c_cpp_rm = ['compile_commands.json', 'build/']
let s:go_rm = ['go.sum', 'go.mod']

let g:LanguageClient_rootMarkers = {
      \ 'python': s:general_rm + s:py_rm,
      \ 'javascript': s:general_rm +  s:js_ts_rm,
      \ 'typescript':s:general_rm + s:js_ts_rm,
      \ 'c': s:general_rm + s:c_cpp_rm,
      \ 'cpp': s:general_rm + s:c_cpp_rm,
      \ 'go': s:general_rm + s:go_rm,
      \ 'swift': s:general_rm,
      \ }


let g:LanguageClient_fzfOptions = '$FZF_DEFAULT_OPTS'
let g:LanguageClient_hasSnippetSupport = 1

let b:LSP_hl = 0
function! ToggleHightlight(is_running) abort
  if a:is_running.result && b:LSP_hl == 0
    call LanguageClient#textDocument_documentHighlight()
    let b:LSP_hl = 1
  elseif a:is_running.result
    call LanguageClient#clearDocumentHighlight()
    let b:LSP_hl = 0
  endif
endfunction

function LC_maps()
  if has_key(g:LanguageClient_serverCommands, &filetype)
    nnoremap <buffer> <silent> <F2> :call LanguageClient_contextMenu()<CR>
    nnoremap <buffer> <silent> <F3> :call LanguageClient#textDocument_references()<CR>
    nnoremap <buffer> <silent> <F4> :call LanguageClient#textDocument_typeDefinition()<CR>
    nnoremap <buffer> <silent> <Leader>th :call LanguageClient#isAlive(function('ToggleHightlight'))<CR>
    nnoremap <buffer> <silent> K :call LanguageClient#textDocument_hover()<CR>
    nnoremap <buffer> <silent> gd :call LanguageClient#textDocument_definition()<CR>
    nnoremap <buffer> <silent> <Leader>rn :call LanguageClient#textDocument_rename()<CR>
  endif
endfunction

autocmd FileType * call LC_maps()
