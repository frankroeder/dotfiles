augroup filetype
  autocmd! BufReadPost,BufNewFile Brewfile set filetype=ruby
  autocmd! BufReadPost,BufNewFile *gitconfig set filetype=gitconfig
  autocmd! BufReadPost,BufNewFile *.cls set filetype=tex
  autocmd! BufReadPost,BufNewFile *.config set filetype=config
	autocmd BufNewFile,BufRead *.Dockerfile set filetype=dockerfile
augroup END
