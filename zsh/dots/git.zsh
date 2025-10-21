# Zsh-specific git configuration (common git aliases are in shared/git.sh)
# https://github.com/robbyrussell/oh-my-zsh/blob/master/plugins/git/git.plugin.zsh
! [ $commands[git] ] && return

# Additional zsh-specific git aliases
alias gbda='git branch --no-color --merged | command grep -vE "^(\*|\s*(master|main|develop|dev)\s*$)" | command xargs -n 1 git branch -d'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'

alias gcn!='git commit -v --no-edit --amend'
alias gcan!='git commit -v -a --no-edit --amend'
alias gcans!='git commit -v -a -s --no-edit --amend'
alias gcfle='git config --local --edit'
gcm() {
  if [[ $(git branch | grep 'master') ]]; then
    git checkout master
  elif [[ $(git branch | grep 'main') ]]; then
    git checkout main
  else
    echo "No branch named master or main found."
  fi
}
gcd() {
  if [[ $(git branch | grep 'develop') ]]; then
    git checkout develop
  elif [[ $(git branch | grep 'dev') ]]; then
    git checkout dev;
  else
    echo "No branch named develop or dev found."
  fi
}
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gcs='git commit -S'

alias gdct='git describe --tags `git rev-list --tags --max-count=1`'
alias gdt='git diff-tree --no-commit-id --name-only -r'

# List contributors
alias glc='git shortlog --email --numbered --summary'

alias glgm='git log --graph --max-count=10'
# Pretty log formats (zsh-specific)
alias glol="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
alias glols="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --stat"
alias glod="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'"
alias glods="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)%Creset' --date=short"
alias glola="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --all"

alias gmom='git merge origin/master'
alias gmt='git mergetool --no-prompt'
alias gmtvim='git mergetool --no-prompt --tool=vimdiff'
alias gmum='git merge upstream/master'
alias gpoat='git push origin --all && git push origin --tags'
alias gpu='git push upstream'
alias grbd='git rebase develop'
alias grbm='git rebase master'
alias groh='git reset origin/$(git_current_branch) --hard'
alias grmv='git remote rename'
alias grset='git remote set-url'
alias grup='git remote update'

alias gsd='git svn dcommit'
alias gsh='git show'
alias gsi='git submodule init'
alias gsps='git show --pretty=short --show-signature'
alias gsr='git svn rebase'
alias gsu='git submodule update'
alias gsurr='git submodule update --recursive --remote'

alias gts='git tag -s'

alias gunignore='git update-index --no-assume-unchanged'
alias gunwip='git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'
alias gupv='git pull --rebase -v'
alias gupav='git pull --rebase --autostash -v'
alias glum='git pull upstream master'
alias gwch='echo "PLEASE USE glgp"'

# Start web-based visualizer.
alias gw='git instaweb --httpd=webrick'
gbrowse() {
  $BROWSER $(git config --get remote.origin.url | sed -e 's/com:/com\//' | sed -e 's/^git@/https:\/\//')
}
