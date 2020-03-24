let g:ale_enabled = 1
let g:ale_completion_enabled = 0
let g:ale_sign_error = '●'
let g:ale_sign_warning = '●'

nmap <silent> gn <Plug>(ale_next_wrap)
nmap <silent> gp <Plug>(ale_previous_wrap)

nmap <silent> <F12> <Plug>(ale_fix)
nmap <silent> <Leader>at <Plug>(ale_toggle)
nmap <silent> <Leader>l <Plug>(ale_lint)

let g:ale_javascript_eslint_use_global = 1

let g:ale_python_flake8_use_global = 1
let g:ale_python_flake8_executable = $HOME.'/Library/Python/'.$PY_VERSION.'/bin/flake8'
let b:ale_python_autopep8_use_global = 1
let g:ale_python_autopep8_executable = $HOME.'/Library/Python/'.$PY_VERSION.'/bin/autopep8'

let g:ale_fixers = {
      \'python': ['yapf']
      \}

let g:ale_linters = {
      \'python': ['flake8'],
      \'go': ['gofmt', 'golint'],
      \'javascript': ['eslint'],
      \ 'sh': ['language_server'],
      \}
