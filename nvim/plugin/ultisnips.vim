let g:UltiSnipsExpandTrigger="<C-L>"
let g:UltiSnipsJumpForwardTrigger="<C-J>"
let g:UltiSnipsJumpBackwardTrigger="<C-K>"

let g:UltiSnipsEnableSnipMate=0
let g:snips_author = 'Frank Roeder'
let g:ultisnips_javascript = {
      \ 'keyword-spacing': 'always',
      \ 'semi': 'never',
      \ 'space-before-function-paren': 'always',
      \ }
let g:UltiSnipsSnippetDirectories=[$DOTFILES.'/nvim/ultisnips']
