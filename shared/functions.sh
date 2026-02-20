#!/usr/bin/env bash
# General functions shared between bash and zsh
# No external dependencies required

# Create directory and cd into it
mcd() {
  builtin mkdir -p "$@" && cd "$_"
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

# Move to trash with confirmation and undo support
del() {
  local path
  local files=""
  local dst
  local trash_dir

  # Use ~/.Trash for both macOS and Linux
  trash_dir="$HOME/.Trash"
  mkdir -p "$trash_dir"

  echo -n "Do you wish to move the following files to the trash: $@ (y/n)? "
  read -r answer

  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    echo "Yes"

    for path in "$@"; do
      # Skip if it's a flag
      if [ "${path#-}" != "$path" ]; then
        continue
      fi

      dst="${path##*/}"

      # Append random suffix if file exists in trash
      while [ -e "$trash_dir/$dst" ]; do
        dst="${dst}_${RANDOM}"
      done

      /bin/mv -fv "$path" "$trash_dir/$dst"

      # Build space-separated list of files
      if [ -z "$files" ]; then
        files="$dst"
      else
        files="$files $dst"
      fi
    done

    export DEL_PWD=$(pwd)
    export DEL_FILES="$files"
    export DEL_TRASH_DIR="$trash_dir"
  else
    echo "canceled..."
  fi
}

# Extract archives
extract() {
  # Check if a file was provided as an argument
  if [ $# -eq 0 ]; then
    echo "Usage: extract <file_to_extract>"
    return 1
  fi

  local FILE="$1"
  if [ ! -f "$FILE" ]; then
    echo "'$FILE' is not a valid file"
    return 1
  fi

  local filename=$(basename "$FILE")
  case "$filename" in
    *.tar.bz2|*.tar.gz|*.tar.Z|*.tar.xz)
      local foldername="${filename%.*.*}"
      ;;
    *)
      local foldername="${filename%.*}"
      ;;
  esac
  local fullpath=$(realpath "$FILE")
  local current_dir=$(pwd)

  if [ -d "$foldername" ]; then
    echo -n "'$foldername' already exists. Do you want to overwrite it? (y/N) "
    read -r REPLY
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Extraction cancelled."
      return 0
    fi
    rm -rf "$foldername"
  fi

  mkdir -p "$foldername"
  cd "$foldername" || return 1

  case $FILE in
    *.tar.bz2|*.tb2|*.tbz|*.tbz2) tar -jxf "$fullpath" ;;
    *.tar.gz|*.tar.Z|*.taz|*.tgz) tar -zxf "$fullpath" ;;
    *.tar.xz|*.txz) tar -Jxf "$fullpath" ;;
    *.tar) tar -xf "$fullpath" ;;
    *.zip) unzip -q "$fullpath" ;;
    *.dmg)
      local mount_point="/Volumes/$foldername"
      hdiutil attach -mountpoint "$mount_point" "$fullpath" -nobrowse
      cp -R "$mount_point"/* .
      hdiutil detach "$mount_point"
      ;;
    *.bz2) bunzip2 -c "$fullpath" > "${filename%.bz2}" ;;
    *.gz) gunzip -c "$fullpath" > "${filename%.gz}" ;;
    *.xz) unxz -c "$fullpath" > "${filename%.xz}" ;;
    *.Z) uncompress -c "$fullpath" > "${filename%.Z}" ;;
    *.7z) 7z x "$fullpath" ;;
    *.zst) zstd -d "$fullpath" ;;
    *.tar.zst) tar --zstd -xf "$fullpath" ;;
    *.rar) unrar x "$fullpath" ;;
    *)
      echo "'$FILE' cannot be extracted via extract()"
      cd "$current_dir" || return 1
      rm -r "$foldername"
      return 1
      ;;
  esac

  if [ $? -eq 0 ]; then
    echo "Extracted '$FILE' to '$foldername'"
  else
    echo "Extraction failed for '$FILE'"
    cd "$current_dir" || return 1
    rm -r "$foldername"
    return 1
  fi

  cd "$current_dir" || return 1
}

# Overwrite man with different colors
man() {
  env \
    LESS_TERMCAP_mb=$(tput setaf 1) \
    LESS_TERMCAP_md=$(tput setaf 4) \
    LESS_TERMCAP_me=$(tput sgr0) \
    LESS_TERMCAP_so=$(tput setab 4; tput bold; tput setaf 7) \
    LESS_TERMCAP_se=$(tput rmso; tput sgr0) \
    LESS_TERMCAP_us=$(tput bold; tput smul; tput setaf 2) \
    LESS_TERMCAP_ue=$(tput rmul; tput sgr0) \
    LESS_TERMCAP_mr=$(tput rev) \
    LESS_TERMCAP_mh=$(tput dim) \
    LESS_TERMCAP_ZN=$(tput ssubm) \
    LESS_TERMCAP_ZV=$(tput rsubm) \
    LESS_TERMCAP_ZO=$(tput ssupm) \
    LESS_TERMCAP_ZW=$(tput rsupm) \
    man "$@"
}

# Clean Python cache files
pyclean() {
  find . -type f -name "*.py[cod]" -exec rm -v {} \;
  find . -type d -name "__pycache__" -exec rm -rfv {} +
}

# Generate random password
rndpassword() {
  LC_ALL=C tr -dc "[:alnum:]" < /dev/urandom | head -c "${1:-64}"
  echo
}

# Undo del (restore from trash)
undo_del() {
  if [ -n "$DEL_FILES" ] && [ -n "$DEL_PWD" ]; then
    local trash_dir

    # Use the trash directory from del() if set, otherwise use ~/.Trash
    if [ -n "$DEL_TRASH_DIR" ]; then
      trash_dir="$DEL_TRASH_DIR"
    else
      trash_dir="$HOME/.Trash"
    fi

    for file in $(echo "$DEL_FILES" | tr -s " " "\012"); do
      command mv -fv "$trash_dir/$file" "$DEL_PWD"
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
  if command -v nvim >/dev/null 2>&1; then
    nvim -d "$@"
  else
    vimdiff "$@"
  fi
}

# Tree with ignore patterns
tre() {
  if ! command -v tree >/dev/null 2>&1; then
    echo "tree is not installed"
    return 1
  fi

  local ignore
  if [ -n "$DOTFILES" ] && [ -f "$DOTFILES/ignore" ]; then
    ignore=$(paste -d\| -s "$DOTFILES/ignore")
  else
    ignore="node_modules|.git|.venv|__pycache__|dist|build"
  fi

  if [ -z "$1" ]; then
    tree -aC -I "$ignore" --dirsfirst
  else
    tree -aC -I "$ignore" -L "$1"
  fi
}

# Print PATH entries on separate lines with colors
lpath() {
  echo "$PATH" | tr ":" "\n" | \
    awk -v user="$USER" '{
      gsub(/\/usr/, "\033[32m/usr\033[0m");
      gsub(/\/bin/, "\033[34m/bin\033[0m");
      gsub(/\/opt/, "\033[36m/opt\033[0m");
      gsub(/\/sbin/, "\033[35m/sbin\033[0m");
      gsub(/\/local/, "\033[33m/local\033[0m");
      gsub("/"user, "\033[31m/"user"\033[0m");
      print
    }'
}

catcsv() {
  cat "$1"  | column -t -s,
}
