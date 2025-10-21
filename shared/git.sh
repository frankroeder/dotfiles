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
