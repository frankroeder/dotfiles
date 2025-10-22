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

# Move to trash with confirmation and undo support
del() {
  local path
  local files=""
  local dst

  echo -n "Do you wish to move the following files to the trash: $@ (y/n)? "
  read answer

  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    echo "Yes"

    for path in "$@"; do
      # Skip if it's a flag
      if [ "${path#-}" != "$path" ]; then
        continue
      fi

      dst="${path##*/}"

      # Append random suffix if file exists in trash
      while [ -e ~/.Trash/"$dst" ]; do
        dst="${dst}_${RANDOM}"
      done

      /bin/mv -fv "$path" ~/.Trash/"$dst"

      # Build space-separated list of files
      if [ -z "$files" ]; then
        files="$dst"
      else
        files="$files $dst"
      fi
    done

    export DEL_PWD=$(pwd)
    export DEL_FILES="$files"
  else
    echo "canceled..."
  fi
}

# Empty trash and clean caches
emptytrash() {
  # Empty the main trash
  local TRASH="$HOME/.Trash/*"
  if [ "${#TRASH[@]}" -gt 0 ]; then
    for t in $HOME/.Trash/*; do
      sudo rm -rf "$t"
    done
  fi

  # Clean package manager caches
  if command -v pip >/dev/null 2>&1; then
    pip cache purge
  fi
  if command -v conda >/dev/null 2>&1; then
    conda clean --all -y
  fi
  if command -v uv >/dev/null 2>&1; then
    uv cache prune
  fi

  # OS-specific cleanup
  if [ "$OSTYPE" = "Darwin" ]; then
    # Remove homebrew cache
    rm -rf "$(brew --cache)"

    # Empty trashes on all mounted volumes
    local VOL_TRASH="/Volumes/*/.Trashes"
    if [ "${#VOL_TRASH[@]}" -gt 0 ]; then
      sudo rm -rfv /Volumes/*/.Trashes
    fi

    # Clear system logs to improve shell startup speed
    sudo rm -rfv /private/var/log/asl/*.asl

    # Clear download history from quarantine
    sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* \
      'delete from LSQuarantineEvent'

  elif [ "$OSTYPE" = "Linux" ]; then
    # APT cleanup
    sudo apt autoclean -y
    sudo apt clean -y
    sudo apt autoremove -y

    # Clear thumbnail cache
    local THUMBNAIL_CACHE="$HOME/.cache/thumbnails"
    [ -d "$THUMBNAIL_CACHE" ] && rm -rfv "$THUMBNAIL_CACHE"/*
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

# System information
ii() {
  echo -e "\nYou are logged on:"; hostname
  echo -e "\nSoftware Version:";
  if [ "$OSTYPE" = "Darwin" ]; then
    sw_vers
  else
    lsb_release -a
  fi
  echo -e "\nArchitecture Type:"; arch
  echo -e "\nCPU Info:";
  if [ "$OSTYPE" = "Darwin" ]; then
    sysctl -n machdep.cpu.brand_string
  else
    cat /proc/cpuinfo | grep 'model name' | uniq
  fi
  echo -e "\nAdditional information:"; uname -a
  echo -e "\nUsers logged on:"; w -h
  echo -e "\nCurrent date:"; date
  echo -e "\nMachine stats:"; uptime
  echo -e "\nIP for Local Network:";
  if [ "$OSTYPE" = "Darwin" ]; then
    ipconfig getifaddr en0
  else
    hostname -i
  fi
  echo -e "\nIP for Interconnection:"; curl -4 https://icanhazip.com
  echo -e "\nHardware Overview:";
  if [ "$OSTYPE" = "Darwin" ]; then
    system_profiler SPHardwareDataType | tail -n 14 | tr -d " " | sed 's/:/: /g'
  else
    lscpu
  fi
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
    for file in $(echo $DEL_FILES | tr -s " " "\012"); do
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
    tree -aC -I "$ignore" --dirsfirst "$@"
  else
    tree -aC -I "$ignore" -L "$1"
  fi
}

# Print PATH entries on separate lines
lpath() {
  echo "$PATH" | tr ":" "\n"
}
