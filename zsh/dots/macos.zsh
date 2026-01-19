[[ $OSTYPE != 'Darwin' ]] && return

alias f='open -a Finder ./'
alias preview='open -a /System/Applications/Preview.app'
test -d "/Applications/Skim.app" && alias skim='open -a /Applications/Skim.app'
test -d "/Applications/Firefox.app" && alias firefox="/Applications/Firefox.app/Contents/MacOS/firefox"
alias icloud="cd /Users/$USER/Library/Mobile\ Documents/com~apple~CloudDocs"

# CPU and MEM Monitoring
alias cpu="top -F -R -o cpu"
alias mem="top -F -o rsize"
alias ttop="top -R -F -s 10 -o rsize"

# Lock the screen (when going AFK)
alias lock='/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend'
alias afk="open -a /System/Library/CoreServices/ScreenSaverEngine.app"
alias wifion='networksetup -setairportpower en0 on'
alias wifioff='networksetup -setairportpower en0 off'

# Recursively delete all .DS_Store files
rmds_store() {
  find ~/ -type f -name '*.DS_Store' ! -path '~/Library' -ls -delete
}

# Clear DNS cache
flushdns() {
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
  sudo killall mDNSResponderHelper
}

# Clean up LaunchServices to remove duplicates in the "Open With" menu
rmls() {
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
  killall Finder
}

mergepdf() {
  if [ $# -eq 0 ]; then
    echo "# Merge PDF files, Usage: \`mergepdf input{1,2,3}.pdf\`"
    return
  fi
  gs -dQUIET -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=merged.pdf $@
  echo "Merged as merged.pdf"
}


alias displays="system_profiler SPDisplaysDataType"
alias cpuinfo="sysctl -n machdep.cpu.brand_string"
alias hardwareports='networksetup -listallhardwareports'
alias mute="osascript -e 'set volume output muted true'"
alias unmute="osascript -e 'set volume output muted false'"
alias lstcp='lsof -i -n -P | grep TCP'
alias lsudp='lsof -i -n -P | grep UDP'
alias systail='tail -f /var/log/system.log'
alias localip="ipconfig getifaddr en0"
alias showdns='networksetup -getdnsservers Wi-Fi'
alias afplay='afplay -q 1'
alias speedtest='networkQuality'
alias stayawake='caffeinate -u -t 5400'

alias pbpubkey='pbcopy < ~/.ssh/id_rsa.pub'
alias pbtrim="tr -d '\n' | pbcopy"
alias pbpwd="pwd | tr -d '\n' | pbcopy"
pbcat() {
  cat "$@" | pbcopy
}
pbcurl() {
  if [ -z "$1" ]; then
    URL=$(puturl)
  else
    URL=${1}
  fi
  curl -s "$URL" | pbcopy
  echo "Copied the content from $URL to the clipboard."
}
applenotifications(){
  log show --predicate 'eventMessage contains[c] "register name"' --last 1h | awk '{ print $12 }' | sort | uniq -c | sort | less
}
alias yabailogs="tail -f $HOMEBREW_PREFIX/var/log/yabai/*.log"
alias watchsketchybar="tail -F /opt/homebrew/var/log/sketchybar/sketchybar.out.log /tmp/sketchybar-top.*"
alias screensaver="open /System/Library/CoreServices/ScreenSaverEngine.app"
alias agents="$EDITOR $HOME/Library/Mobile\ Documents/com~apple~CloudDocs/configs/AGENTS.md"
