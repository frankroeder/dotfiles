lua vim.lsp.set_log_level("error")

let pyls_setting = {
      \ "pyls": {
      \   "enable": v:true,
      \   "commandPath": exepath('pyls'),
      \   "plugins" : {
      \     "jedi_completion" : { "enabled" : v:true, },
      \     "jedi_hover" : { "enabled" : v:true, },
      \     "jedi_references" : { "enabled" : v:true, },
      \     "jedi_signature_help" : { "enabled" : v:true, },
      \     "jedi_symbols" : {
      \       "enabled" : v:true,
      \       "all_scopes" : v:true,
      \     },
      \     "mccabe" : {
      \       "enabled" : v:false,
      \     },
      \     "preload" : { "enabled" : v:true, },
      \     "pycodestyle" : { "enabled" : v:true, },
      \     "pydocstyle" : {
      \       "enabled" : v:false,
      \       "match" : "(?!test_).*\\.py",
      \       "matchDir" : "[^\\.].*",
      \     },
      \     "pyflakes" : { "enabled" : v:true, },
      \     "rope_completion" : { "enabled" : v:true, },
      \     "yapf" : { "enabled" : v:true, },
      \     }}}

lua require'nvim_lsp'.pyls.setup{
      \ cmd = { 'pyls', '--log-file' , '/tmp/pyls.log' };
      \ settings = pyls_setting;
      \ }
lua require'nvim_lsp'.clangd.setup{}
lua require'nvim_lsp'.tsserver.setup{}
lua require'nvim_lsp'.html.setup{}
lua require'nvim_lsp'.cssls.setup{filetypes = {"css", "scss", "sass", "less"}}
lua require'nvim_lsp'.gopls.setup{
      \ cmd = { 'gopls', '-logfile', '/tmp/gopls.log' };
      \ settings = {
      \   gopls = {
      \     usePlaceholders = true;
      \     completeUnimported = true;
      \   }
      \ }
      \}
lua require'nvim_lsp'.sourcekit.setup{}

" autocmd Filetype go setlocal omnifunc=v:lua.vim.lsp.omnifunc
" use omni completion provided by lsp
set omnifunc=lsp#omnifunc

function! LSPRename()
    let s:newName = input('Enter new name: ', expand('<cword>'))
    echom "s:newName = " . s:newName
    lua vim.lsp.buf.rename(s:newName)
endfunction

function! LSPSetMappings()
    setlocal omnifunc=v:lua.vim.lsp.omnifunc
    nnoremap <silent> <buffer> gd    <cmd>lua vim.lsp.buf.declaration()<CR>
    nnoremap <silent> <buffer> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
    nnoremap <silent> <buffer> K     <cmd>lua vim.lsp.buf.hover()<CR>
    nnoremap <silent> <buffer> gD    <cmd>lua vim.lsp.buf.implementation()<CR>
    nnoremap <silent> <buffer> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
    nnoremap <silent> <buffer> 1gD   <cmd>lua vim.lsp.buf.type_definition()<CR>
    nnoremap <silent> <buffer> gr    <cmd>lua vim.lsp.buf.references()<CR>
    nnoremap <silent> <buffer> rn <cmd>lua vim.lsp.buf.rename()<CR>
endfunction

au FileType c,python,javascript,typescript,swift,go,html,css :call LSPSetMappings()
