# Fuzzy Functions
# ------------------------------------------------------------------------------

ii() {
  echo -e "\n${ORANGE}You are logged on:$RESET"; hostname
  echo -e "\n${LIGHT_BLUE}Software Version:$RESET"; sw_vers
  echo -e "\n${LIGHT_BLUE}CPU Info:$RESET"; cpuinfo
  echo -e "\n${LIGHT_BLUE}Additionnal information:$RESET "; uname -a
  echo -e "\n${LIGHT_BLUE}Users logged on:$RESET "; w -h
  echo -e "\n${LIGHT_BLUE}Current date:$RESET "; date
  echo -e "\n${LIGHT_BLUE}Machine stats:$RESET "; uptime
  echo -e "\n${LIGHT_BLUE}IP for Local Network:$RESET"; ipconfig getifaddr en0
  echo -e "\n${LIGHT_BLUE}IP for Inter Connection:$RESET"; curl -4 icanhazip.com
  echo -e "\n${LIGHT_BLUE}HardwareOverview:$RESET";
  system_profiler SPHardwareDataType | tail -n 14  | tr -d " " | sed 's/:/: /g';
}

# Create directory and cd into it
mcd () {
  mkdir -p "$@" && cd "$_"
}

# cd with following ls
c() {
  builtin cd "$@";clear; ls;
}

# ls with file permissions in octal format
lla(){
 	ls -l  "$@" | awk '
    {
      k=0;
      for (i=0;i<=8;i++)
        k+=((substr($1,i+2,1)~/[rwx]/) *2^(8-i));
      if (k)
        printf("%0o ",k);
      printf(" %9s  %3s %2s %5s  %6s  %s %s %s\n", $3, $6, $7, $8, $5, $9,$10, $11);
    }'
}

# Quick-Look files from the command line
ql () {
  qlmanage -p "$*" >& /dev/null;
}

# Move to macos trash
del () {
  export DEL_FILES="$@"
  export DEL_PWD=$(pwd)
  command mv -fv "$@" ~/.Trash/
}

undo_del () {
  for file in ${DEL_FILES[@]}
  do
    command mv -fv ~/.Trash/$file $DEL_PWD
  done
}

# Determine size of a file or total size of a directory
fs() {
  if [[ -n "$@" ]]; then
    du -sh -- "$@";
  else
    du -sh .[^.]* ./*;
  fi;
}

# macOS dictionary shortcut
dic(){
  open dict://$1
}

weather(){
  curl -4 http://wttr.in/$1
}

moon(){
  curl -4 http://wttr.in/Moon
}

aspelleng(){
  aspell --lang=en_US -c $1
}

aspellger(){
  aspell --lang=de_DE-c $1
}

showdesktopicons(){
  defaults write com.apple.finder CreateDesktop -bool true; killall Finder
}

hidedesktopicons(){
  defaults write com.apple.finder CreateDesktop -bool false; killall Finder
}

showhiddenfiles() {
  defaults write com.apple.Finder AppleShowAllFiles YES
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'
}

hidehiddenfiles() {
  defaults write com.apple.Finder AppleShowAllFiles NO
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'
}

# Overwrite man with different color
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

# Use Mac OS Preview to open a man page in a more handsome format
manp() {
  man -t "$@" | open -f -a /Applications/Preview.app
}

# Set DNS to 1.1.1.1
gooddns(){
  networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1 2606:4700:4700::1111 \
    2606:4700:4700::1001
}
# Set Google DNS
googledns(){
  networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4 2001:4860:4860::8888 \
  2001:4860:4860::8844
}

defaultdns(){
  networksetup -setdnsservers Wi-Fi empty
}

# `tre` is a shorthand for `tree` with hidden files and color enabled, ignoring
# some directories, listing directories first.
tre() {
  if [ -z "${1}" ]; then
    tree -aC -I '.git|node_modules|venv' --dirsfirst "$@";
  else
    tree -aC -I '.git|node_modules|venv' -L $1;
  fi
}

# watch all dns queries
monitordnsqueries(){
  tshark -Y "dns.flags.response == 1" -Tfields \
  -e frame.time_delta \
  -e dns.qry.name \
  -e dns.a \
  -Eseparator=,
}

# Show how much RAM application uses.
# Usage: ram safari
ram() {
  local SUM
  local APP="$1"
  if [ -z "$APP" ]; then
    echo "First argument - pattern to grep from processes"
  else
    SUM=0
    for i in `ps aux | grep -i "$APP" | grep -v "grep" | awk '{print $6}'`; do
      SUM=$(($i + $SUM))
    done
    SUM=$(echo "scale=2; $SUM / 1024.0" | bc)
    if [[ $SUM != "0" ]]; then
      printf "${BLUE}${APP}${RESET} uses ${GREEN}${SUM}${RESET} MBs of RAM."
    else
      printf "There are no processes with pattern '${BLUE}${APP}${RESET}' are running."
    fi
  fi
}

# Get a character’s Unicode code point
codepoint() {
  perl -e "use utf8; print sprintf('U+%04X', ord(\"$@\"))";
  # print a newline unless we’re piping the output to another program
  if [ -t 1 ]; then
    echo ""; # newline
  fi;
}

# Get cheat sheet of command from cheat.sh
# Usage: cheat <cmd>
cheat(){
  curl https://cheat.sh/$@
}
