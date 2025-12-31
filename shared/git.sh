#!/usr/bin/env sh
# Git aliases and functions shared between bash and zsh

! command -v git >/dev/null 2>&1 && return

alias g='git'

# Add
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gau='git add --update'
alias gav='git add --verbose'
alias gap='git apply'

# Branch
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gbl='git blame -b -w'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'

# Commit
alias gc='git commit'
alias gcv='git commit -v'
alias gc!='git commit -v --amend'
alias gca='git commit -v -a'
alias gca!='git commit -v -a --amend'
alias gcaa='git commit -a --amend -C HEAD'
alias gcam='git commit -a -m'
alias gcsm='git commit -s -m'
alias gcmsg='git commit -m'
alias gfixup='git commit --fixup'
# Undo last commit but keep changes
alias gundo='git reset --soft HEAD~1'

# Checkout
alias gco='git checkout'
alias gcb='git checkout -b'

# Config
alias gcf='git config --list'

# Clone
alias gcl='git clone --recurse-submodules'
alias gclean='git clean -id'
alias gpristine='git reset --hard && git clean -dfx'

# Diff
alias gd='git diff'
alias gdca='git diff --cached'
alias gdcw='git diff --cached --word-diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'

# Fetch
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gfo='git fetch origin'

# Grep
alias gg='git grep --color=auto --line-number'

# Pull
alias gl='git pull'
alias glrs='git pull --recurse-submodules'

# Log
alias glg='git log --stat'
alias glgp='git log --stat -p'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'

# Merge
alias gm='git merge'
alias gma='git merge --abort'

# Push
alias gp='git push'
alias gpd='git push --dry-run'
alias gpf='git push --force-with-lease'
alias gpf!='git push --force'
alias gpv='git push -v'

# Remote
alias gr='git remote'
alias gra='git remote add'
alias grv='git remote -v'
alias grrm='git remote remove'

# Rebase
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase -i'
alias grbs='git rebase --skip'

# Reset
alias grh='git reset'
alias grhh='git reset --hard'
alias gru='git reset --'

# Remove
alias grm='git rm'
alias grmc='git rm --cached'

# Status
alias gst='git status'
alias gss='git status -s'
alias gsb='git status -sb'

# Stash
alias gsta='git stash save'
alias gstaa='git stash apply'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --text'
alias gstall='git stash --all'

# Tag
alias gt='git tag'
alias gtv='git tag | sort -V'

# Update
alias gup='git pull --rebase'
alias gupa='git pull --rebase --autostash'

# Navigate to git root
alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'

# Bisect
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'

# Branch management
alias gbda='git branch --no-color --merged | command grep -vE "^(\\*|\\s*(master|main|develop|dev)\\s*$)" | command xargs -n 1 git branch -d'

# Commit variations
alias gcn!='git commit -v --no-edit --amend'
alias gcan!='git commit -v -a --no-edit --amend'
alias gcans!='git commit -v -a -s --no-edit --amend'
alias gcfle='git config --local --edit'
alias gcs='git commit -S'

# Cherry-pick
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'

# Count and contributors
alias gcount='git shortlog -sn'
alias glc='git shortlog --email --numbered --summary'
alias gcontrib='git shortlog -sn --no-merges'

# Describe and diff-tree
alias gdct='git describe --tags `git rev-list --tags --max-count=1`'
alias gdt='git diff-tree --no-commit-id --name-only -r'

# Log
alias glgm='git log --graph --max-count=10'
alias glol="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
alias glols="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --stat"
alias glod="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'"
alias glods="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)%Creset' --date=short"
alias glola="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --all"

# Merge
alias gmom='git merge origin/master'
alias gmt='git mergetool --no-prompt'
alias gmtvim='git mergetool --no-prompt --tool=vimdiff'
alias gmum='git merge upstream/master'

# Push
alias gpoat='git push origin --all && git push origin --tags'
alias gpu='git push upstream'

# Rebase
alias grbd='git rebase develop'
alias grbm='git rebase master'

# Remote
alias groh='git reset origin/$(git rev-parse --abbrev-ref HEAD) --hard'
alias grmv='git remote rename'
alias grset='git remote set-url'
alias grup='git remote update'

# SVN
alias gsd='git svn dcommit'
alias gsr='git svn rebase'

# Show
alias gsh='git show'
alias gsps='git show --pretty=short --show-signature'

# Submodule
alias gsi='git submodule init'
alias gsu='git submodule update'
alias gsurr='git submodule update --recursive --remote'

# Tag
alias gts='git tag -s'

# Update index
alias gunignore='git update-index --no-assume-unchanged'
alias gunwip='git log -n 1 | grep -q -c "\\-\\-wip\\-\\-" && git reset HEAD~1'

# Pull
alias gupv='git pull --rebase -v'
alias gupav='git pull --rebase --autostash -v'
alias glum='git pull upstream master'

# Checkout main/master or develop/dev branch functions
gcm() {
  if git branch | grep -q 'master'; then
    git checkout master
  elif git branch | grep -q 'main'; then
    git checkout main
  else
    echo "No branch named master or main found."
  fi
}

gcd() {
  if git branch | grep -q 'develop'; then
    git checkout develop
  elif git branch | grep -q 'dev'; then
    git checkout dev
  else
    echo "No branch named develop or dev found."
  fi
}
