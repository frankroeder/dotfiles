# Zsh-specific git configuration (common git aliases are in shared/git.sh)
# https://github.com/robbyrussell/oh-my-zsh/blob/master/plugins/git/git.plugin.zsh
! [ $commands[git] ] && return

# Desktop-specific git aliases and functions (rest are in shared/git.sh for servers)
alias gwch='echo "PLEASE USE glgp"'

# Start web-based visualizer (desktop only)
alias gw='git instaweb --httpd=webrick'

# Open git repository in browser (uses zsh-specific $BROWSER variable)
gbrowse() {
  $BROWSER $(git config --get remote.origin.url | sed -e 's/com:/com\//' | sed -e 's/^git@/https:\/\//')
}
