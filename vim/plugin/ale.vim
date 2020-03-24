let g:ale_enabled = 1
let g:ale_completion_enabled = 0
let g:ale_sign_column_always = 1
let g:ale_sign_error = '●'
let g:ale_sign_warning = '●'
let g:ale_disable_lsp = 1
let g:ale_change_sign_column_color = 1

highlight! ALEErrorSign ctermfg=Red guifg=#e06c75
highlight! ALEWarningSign ctermfg=Yellow guifg=#abb2bf

nmap <silent> gn <Plug>(ale_next_wrap)
nmap <silent> gp <Plug>(ale_previous_wrap)

nmap <silent> <F12> <Plug>(ale_fix)
nmap <silent> <Leader>at <Plug>(ale_toggle)
nmap <silent> <Leader>i :ALEInfo<CR>
nmap <silent> <Leader>l <Plug>(ale_lint)

let g:ale_use_global_executables = 1
let g:ale_python_autopep8_executable = '/usr/local/bin/autopep8'
let g:ale_python_pyflakes_executable = '/usr/local/bin/pyflakes'
let g:ale_c_clangformat_executable = '/usr/local/opt/llvm/bin/clang-format'
let g:ale_c_clangtidy_executable = '/usr/local/opt/llvm/bin/clang-tidy'
let g:ale_javascript_eslint_executable = '/usr/local/bin/eslint'

let g:ale_fixers = {
      \ 'python': ['autopep8'],
      \ 'c': ['clang-format', 'clangtidy'],
      \ 'cpp': ['clang-format', 'clangtidy'],
      \ 'go': ['gofmt', 'goimport'],
      \ 'javascript': ['eslint'],
      \ 'typescript': ['tslint', 'eslint'],
      \ }

let g:ale_linters = {
      \ 'python': ['pyflakes'],
      \ 'go': ['gofmt', 'golint', 'golangci-lint', 'gobuild'],
      \ 'javascript': ['eslint'],
      \ 'typescript': ['eslint'],
      \ 'c': ['clang', 'clangtidy', 'clangd'],
      \ 'cpp': ['clang', 'clangtidy', 'clangd'],
      \ 'help': [],
      \ 'text': [],
      \ 'spec': [],
      \ }
