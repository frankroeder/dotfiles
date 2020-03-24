" Enable deoplete on first InsertEnter
let g:deoplete#enable_at_startup = 0
autocmd InsertEnter * call deoplete#enable()
call deoplete#custom#option('profile', v:true)
call deoplete#enable_logging('WARNING', '/tmp/deoplete.log')
call deoplete#custom#source('_', 'matchers', ['matcher_full_fuzzy'])
call deoplete#custom#source('_', 'converters', ['converter_auto_paren'])

set completeopt-=preview

call deoplete#custom#option({
      \ 'smart_case': v:true,
      \ 'max_list': 30
      \ })

" UltiSnips settings
call deoplete#custom#source('ultisnips', {
      \'matchers': ['matcher_fuzzy'],
      \ 'min_pattern_length': 1
      \ })

" Add vimtex completion source
call deoplete#custom#var('omni', 'input_patterns', {
      \ 'tex': g:vimtex#re#deoplete
      \ })

call deoplete#custom#source('LanguageClient',
      \ 'min_pattern_length',
      \ 2)

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<Tab>" :
      \ deoplete#complete()

inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function() abort
  return deoplete#close_popup() . "\<CR>"
endfunction
