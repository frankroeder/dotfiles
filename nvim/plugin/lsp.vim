lua require('lsp')
setlocal omnifunc=v:lua.vim.lsp.omnifunc

function! LSPRename()
    let s:newName = input('Enter new name: ', expand('<cword>'))
    echom "s:newName = " . s:newName
    lua vim.lsp.buf.rename(s:newName)
endfunction

function! LSPSetMappings()
    nnoremap <silent> <buffer> <F2> <cmd>lua vim.lsp.buf.signature_help()<CR>
    nnoremap <silent> <buffer> <F3> <cmd>lua vim.lsp.buf.references()<CR>
    nnoremap <silent> <buffer> <F4> <cmd>lua vim.lsp.buf.type_definition()<CR>
    nnoremap <silent> <buffer> gd    <cmd>lua vim.lsp.buf.declaration()<CR>
    nnoremap <silent> <buffer> K     <cmd>lua vim.lsp.buf.hover()<CR>
    nnoremap <silent> <buffer> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
    nnoremap <silent> <buffer> gD    <cmd>lua vim.lsp.buf.implementation()<CR>
    nnoremap <silent> <buffer> rn    <cmd>lua vim.lsp.buf.rename()<CR>
endfunction

au FileType c,cpp,python,javascript,typescript,swift,go,html,css :call LSPSetMappings()
