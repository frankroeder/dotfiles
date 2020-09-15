" Enable deoplete on first InsertEnter
let g:deoplete#enable_at_startup = 0
autocmd InsertEnter * call deoplete#enable()

autocmd InsertLeave * silent! pclose!

call deoplete#custom#option('profile', v:true)
call deoplete#enable_logging('WARNING', '/tmp/deoplete.log')
call deoplete#custom#source('_', 'matchers', ['matcher_full_fuzzy',
      \ 'matcher_length'])
set completeopt-=preview

call deoplete#custom#option({
      \ 'smart_case': v:true,
      \ 'max_list': 30,
      \ 'ignore_sources': { '_': ['around', 'member'] },
      \ })

"Bug: Cannot access this variable from vimtex, so define it here
let g:vimtex#re#deoplete = '\\(?:'
      \ .  '(?:\w*cite|Cite)\w*\*?(?:\s*\[[^]]*\]){0,2}\s*{[^}]*'
      \ . '|(?:\w*cites|Cites)(?:\s*\([^)]*\)){0,2}'
      \     . '(?:(?:\s*\[[^]]*\]){0,2}\s*\{[^}]*\})*'
      \     . '(?:\s*\[[^]]*\]){0,2}\s*\{[^}]*'
      \ . '|(text|block)cquote\*?(?:\s*\[[^]]*\]){0,2}\s*{[^}]*'
      \ . '|(for|hy)\w*cquote\*?{[^}]*}(?:\s*\[[^]]*\]){0,2}\s*{[^}]*'
      \ . '|\w*ref(?:\s*\{[^}]*|range\s*\{[^,}]*(?:}{)?)'
      \ . '|hyperref\s*\[[^]]*'
      \ . '|includegraphics\*?(?:\s*\[[^]]*\]){0,2}\s*\{[^}]*'
      \ . '|(?:include(?:only)?|input|subfile)\s*\{[^}]*'
      \ . '|([cpdr]?(gls|Gls|GLS)|acr|Acr|ACR)[a-zA-Z]*\s*\{[^}]*'
      \ . '|(ac|Ac|AC)\s*\{[^}]*'
      \ . '|includepdf(\s*\[[^]]*\])?\s*\{[^}]*'
      \ . '|includestandalone(\s*\[[^]]*\])?\s*\{[^}]*'
      \ . '|(usepackage|RequirePackage|PassOptionsToPackage)(\s*\[[^]]*\])?\s*\{[^}]*'
      \ . '|documentclass(\s*\[[^]]*\])?\s*\{[^}]*'
      \ . '|begin(\s*\[[^]]*\])?\s*\{[^}]*'
      \ . '|end(\s*\[[^]]*\])?\s*\{[^}]*'
      \ . '|\w*'
      \ .')'

" Add vimtex completion source
call deoplete#custom#var('omni', 'input_patterns', {
      \ 'tex': g:vimtex#re#deoplete
      \ })

call deoplete#custom#source('lsp', {
      \ 'min_pattern_length': 2,
      \ 'converters': ['converter_auto_paren', 'converter_remove_overlap']
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
