#!/usr/bin/env bash
# Linux-specific utilities shared between bash and zsh
# Only sourced on Linux systems

# Only run on Linux
[ "$(uname -s)" != "Linux" ] && return

# List real (non-system) users
realusers() {
  awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd
}

# Show all date format options
alias datehelp='for F in {a..z} {A..Z} :z ::z :::z;do echo $F: $(date +%$F);done|sed "/:[\ \t\n]*$/d;/%[a-zA-Z]/d"'

# Show swap usage sorted by process
alias swaptop='whatswap | grep -E -v "Swap used: 0" |sort -n -k 10'

# Memory usage with smem (if available)
command -v smem >/dev/null 2>&1 && alias swaphogs='smem --totals --autosize --abbreviate'

# GPU aliases (if nvidia-smi available) - note: also in shared/aliases.sh but with different check
command -v nvidia-smi >/dev/null 2>&1 && alias nogpu='export CUDA_VISIBLE_DEVICES=-1'

# Advanced GPU monitoring (if nvitop is installed)
command -v nvitop >/dev/null 2>&1 && alias ntop='nvitop --monitor auto --gpu-util-thresh 50 80 --mem-util-thresh 60 90'
