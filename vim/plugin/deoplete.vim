" Enable deoplete on first InsertEnter
let g:deoplete#enable_at_startup = 0
autocmd InsertEnter * call deoplete#enable()

set completeopt-=preview

call deoplete#custom#option({
      \ 'smart_case': v:true,
      \ 'max_list': 50
      \ })

" UltiSnips settings
call deoplete#custom#source('ultisnips','matchers', ['matcher_fuzzy'] )
call deoplete#custom#source('ultisnips', 'min_pattern_length', 1)

" Add vimtex completion source
call deoplete#custom#var('omni', 'input_patterns', {
      \ 'tex': g:vimtex#re#deoplete
      \})

call deoplete#custom#source('LanguageClient',
      \ 'min_pattern_length',
      \ 2)

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" inoremap <silent><expr> <C-space> deoplete#complete()

inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<Tab>" :
      \ deoplete#complete()

inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

let g:echodoc_enable_at_startup = 1
