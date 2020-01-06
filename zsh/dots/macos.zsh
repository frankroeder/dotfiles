[[ $(uname) != 'Darwin' ]] && return

alias f='open -a Finder ./'
alias repos='cd ~/Documents'
alias dl='cd ~/Downloads'
alias skim='open -a "Skim"'
alias icloud="cd /Users/$USER/Library/Mobile\ Documents/com~apple~CloudDocs"

# Lock the screen (when going AFK)
alias lock='/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend'
alias afk="open -a /System/Library/CoreServices/ScreenSaverEngine.app"
alias wifion='networksetup -setairportpower en0 on'
alias wifioff='networksetup -setairportpower en0 off'

# Recursively delete all .DS_Store files
alias rmds_store="find ~/ -type f -name '*.DS_Store' -ls -delete"

# Clear DNS cache
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper'

# Clean up LaunchServices to remove duplicates in the "Open With" menu
alias rmls="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"

# Merge PDF files, Usage: `mergepdf -o output.pdf input{1,2,3}.pdf`
alias mergepdf='/System/Library/Automator/Combine\ PDF\ Pages.action/Contents/Resources/join.py'

alias displays="system_profiler SPDisplaysDataType"
alias cpuinfo="sysctl -n machdep.cpu.brand_string"
alias hardwareports='networksetup -listallhardwareports'
alias mute="osascript -e 'set volume output muted true'"
alias unmute="osascript -e 'set volume output muted false'"
alias lstcp='lsof -i -n -P | grep TCP'
alias lsudp='lsof -i -n -P | grep UDP'
alias systail='tail -f /var/log/system.log'
alias cpwd="pwd | pbcopy"
alias localip="ipconfig getifaddr en0"
alias showdns='networksetup -getdnsservers Wi-Fi'
alias trimcopy="tr -d '\n' | pbcopy"
alias afplay='afplay -q 1'
