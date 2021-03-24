" Enable deoplete on first InsertEnter
let g:deoplete#enable_at_startup = 0
autocmd InsertEnter * call deoplete#enable()

autocmd InsertLeave * silent! pclose!

call deoplete#custom#option('profile', v:true)
call deoplete#enable_logging('ERROR', '/tmp/deoplete.log')
call deoplete#custom#source('_', 'matchers', ['matcher_full_fuzzy',
      \ 'matcher_length'])
set completeopt-=preview

call deoplete#custom#option({
      \ 'smart_case': v:true,
      \ 'max_list': 20,
      \ 'ignore_sources': { '_': ['around', 'member'] },
      \ })

" Add vimtex completion source
call deoplete#custom#var('omni', 'input_patterns', {
      \ 'tex': g:vimtex#re#deoplete
      \ })

call deoplete#custom#source('lsp', {
      \ 'min_pattern_length': 2,
      \ 'converters': ['converter_remove_paren', 'converter_remove_overlap', 'converter_truncate_abbr', 'converter_truncate_menu', 'converter_auto_delimiter'],
      \ })

call deoplete#custom#source('neosnippet',
      \ 'disabled_syntaxes', ['Comment', 'String'])

" SuperTab behavior
imap <expr><TAB>
      \ pumvisible() ? "\<C-n>" :
      \ neosnippet#expandable_or_jumpable() ?
      \ "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"

inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

" Expand completion with <CR> (deoplete + neosnippets)
imap <expr><CR>
      \ pumvisible() ? (neosnippet#expandable() ?
      \ "\<Plug>(neosnippet_expand_or_jump)" : "\<C-y>") :
      \ "\<CR>"

" dynamic maximum candidate window width
autocmd InsertEnter * call deoplete#custom#source('_', 'max_menu_width',
      \ str2nr(string((winwidth(0) * 0.5))))

let g:deoplete#lsp#use_icons_for_candidates = v:true

" complete filename after "="
set isfname-==
