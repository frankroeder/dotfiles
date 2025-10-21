#!/usr/bin/env sh
# Tmux aliases shared between bash and zsh

! command -v tmux >/dev/null 2>&1 && return

alias ta='tmux attach -t'
alias tad='tmux attach -d -t'
alias ts='tmux new-session -s'
alias tl='tmux list-sessions'
alias tksv='tmux kill-server'
alias tkss='tmux kill-session -t'
