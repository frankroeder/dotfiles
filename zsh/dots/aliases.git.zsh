# Add uncommitted and unstaged changes to the last commit
alias gcaa='git commit -a --amend -C HEAD'
alias gt='git tag'
alias gg='git grep --color=auto --line-number'

# List contributors
alias glc='git shortlog --email --numbered --summary'

# Start web-based visualizer.
alias gw='git instaweb --httpd=webrick'
