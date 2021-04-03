imap <C-K> <Plug>(neosnippet_expand_or_jump)
smap <C-K> <Plug>(neosnippet_expand_or_jump)
xmap <C-K> <Plug>(neosnippet_expand_target)

smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
      \ "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"

if has('conceal')
  set conceallevel=1 concealcursor=niv
endif

let g:neosnippet#disable_runtime_snippets = {
      \   '_' : 1,
      \ }
let g:neosnippet#enable_conceal_markers = 1
let g:snips_author = 'Frank Roeder'
let g:neosnippet#snippets_directory = expand('~/.config/nvim/snippets')
let g:neosnippet#enable_completed_snippet = 1

augroup ClearNeoSnippetMarker
  autocmd!
  autocmd InsertLeave * NeoSnippetClearMarkers
augroup END
