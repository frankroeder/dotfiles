#!/usr/bin/env sh
# General functions shared between bash and zsh
# No external dependencies required

# Create directory and cd into it
mcd() {
  mkdir -p "$@" && cd "$_"
}

# ls with file permissions in octal format
lla() {
  ls -l "$@" | awk '
    {
      k=0;
      for (i=0;i<=8;i++)
        k+=((substr($1,i+2,1)~/[rwx]/) *2^(8-i));
      if (k)
        printf("%0o ",k);
      printf(" %9s  %3s %2s %5s  %6s  %s %s %s\n", $3, $6, $7, $8, $5, $9,$10, $11);
    }'
}

# Get cheat sheet from cheat.sh
cheat() {
  curl "https://cheat.sh/$@"
}

# Retry command until it succeeds
retry() {
  while true; do "$@"; sleep 1; done
}

# Move to trash instead of rm
del() {
  command mv "$@" ~/.Trash
}

# Empty trash
emptytrash() {
  rm -rfv ~/.Trash/*
}

# Extract archives
extract() {
  if [ -f "$1" ]; then
    case $1 in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar e "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)     echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# System information
ii() {
  echo "\nYou are logged on:"; hostname
  echo "\nAdditional information: "; uname -a
  echo "\nUsers logged on: "; w -h
  echo "\nCurrent date: "; date
  echo "\nMachine stats: "; uptime
  echo "\nIP for Inter Connection:"; curl -4 https://icanhazip.com
}

# Overwrite man with different colors
man() {
  env \
    LESS_TERMCAP_mb=$(printf "\e[1;34m") \
    LESS_TERMCAP_md=$(printf "\e[1;34m") \
    LESS_TERMCAP_me=$(printf "\e[0m") \
    LESS_TERMCAP_se=$(printf "\e[0m") \
    LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
    LESS_TERMCAP_ue=$(printf "\e[0m") \
    LESS_TERMCAP_us=$(printf "\e[1;32m") \
      man "$@"
}

# Clean Python cache files
pyclean() {
  find . | grep -E "(__pycache__|\.py[cod]$)" | xargs rm -rvf
}

# Generate random password
rndpassword() {
  LC_ALL=C tr -dc "[:alnum:]" < /dev/urandom | head -c "${1:-64}"
  echo
}

# Undo del (restore from trash)
undo_del() {
  if [ -n "$DEL_FILES" ] && [ -n "$DEL_PWD" ]; then
    for file in $DEL_FILES; do
      command mv -fv ~/.Trash/"$file" "$DEL_PWD"
    done
  else
    echo "No files to restore. Use 'del' first."
  fi
}

# Weather forecast
weather() {
  local request="v2.wttr.in/${1:-Hamburg}"
  [ "${COLUMNS:-80}" -lt 125 ] && request="${request}?n"
  curl -s -H "Accept-Language: ${LANG%_*}" --compressed "$request"
}

# Compare files with nvim diff
ndiff() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: ndiff <file1> <file2> ..."
    return 1
  fi
  command -v nvim >/dev/null 2>&1 && nvim -d "$@" || vimdiff "$@"
}

# Tree with ignore patterns
tre() {
  if ! command -v tree >/dev/null 2>&1; then
    echo "tree is not installed"
    return 1
  fi

  local ignore="node_modules|.git|.venv|__pycache__|dist|build"

  if [ -z "$1" ]; then
    tree -aC -I "$ignore" --dirsfirst
  else
    tree -aC -I "$ignore" -L "$1"
  fi
}
