let g:ale_enabled = 1
let g:ale_completion_enabled = 0
let g:ale_sign_column_always = 1
let g:ale_sign_error = '●'
let g:ale_sign_warning = '●'
let g:ale_disable_lsp = 1
let g:ale_change_sign_column_color = 0

highlight! ALEErrorSign ctermfg=Red guifg=#e06c75
highlight! ALEWarningSign ctermfg=Yellow guifg=#abb2bf

nmap <silent> gn <Plug>(ale_next_wrap)
nmap <silent> gp <Plug>(ale_previous_wrap)

nmap <silent> <F12> <Plug>(ale_fix)
nmap <silent> <Leader>at <Plug>(ale_toggle)
nmap <silent> <Leader>i :ALEInfo<CR>
nmap <silent> <Leader>l <Plug>(ale_lint)

let g:ale_use_global_executables = 1

let g:ale_python_autopep8_executable = exepath('autopep8')
let g:ale_python_yapf_executable = exepath('yapf')
let g:ale_python_pyflakes_executable = exepath('pyflakes')

let g:ale_c_clangformat_executable = exepath('clang-format')
let g:ale_c_clangtidy_executable = exepath('clang-tidy')

let g:ale_javascript_eslint_executable = exepath('eslint')
let g:ale_javascript_eslint_options = '--no-eslintrc'
let g:ale_typescript_tsserver_executable = exepath('tsserver')

let g:ale_fixers = {
      \ 'python': ['yapf', 'autopep8'],
      \ 'c': ['clang-format', 'clangtidy'],
      \ 'cpp': ['clang-format', 'clangtidy'],
      \ 'go': ['gofmt', 'goimport'],
      \ 'javascript': ['eslint'],
      \ 'typescript': ['tslint'],
      \ }

let g:ale_linters = {
      \ 'python': ['pyflakes'],
      \ 'go': ['gofmt', 'golint', 'golangci-lint', 'gobuild'],
      \ 'javascript': ['eslint'],
      \ 'typescript': ['tslint', 'tsserver'],
      \ 'c': ['clang', 'clangtidy', 'clangd'],
      \ 'cpp': ['clang', 'clangtidy', 'clangd'],
      \ 'json': ['jq'],
      \ 'help': [],
      \ 'text': [],
      \ 'spec': [],
      \ }
