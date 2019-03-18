# Alias
# ------------------------------------------------------------------------------
 
# Always use colored output for 'ls'
alias ls="command ls -G"
alias ll='ls -la'
alias la='ls -a'
alias l.='ls -d .*'
alias lsd='ls -l | grep "^d"'
alias cp='nice cp'
alias mv='nice mv'
alias dud='du -d 1 -h'
alias duf='du -sh *'

alias dotfiles='cd ~/.dotfiles'
alias vim=$EDITOR
alias venv='source ./venv/bin/activate'
alias speedtest="wget -O /dev/null http://speed.transip.nl/100mb.bin"
alias vimrc="$EDITOR ~/.dotfiles/vim/init.vim"

# CPU and MEM Monitoring
alias cpu="top -F -R -o cpu"
alias mem="top -F -o rsize"
# List top 5 processes by CPU usage
alias hogs="ps -acrx -o pid,%cpu,command | awk 'NR<=6'"
alias battery="pmset -g ps"
# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'
# Print each function name
alias functions="declare -f | grep '^[a-z].* ()' | sed 's/{$//'"
alias ag="ag --path-to-ignore ${DOTFILES}/ignore" 
alias localip="ipconfig getifaddr en0"
alias :q="exit"

# macOS
alias f='open -a Finder ./'
alias repos='cd ~/Documents'
alias des='cd ~/Desktop' 
alias dl='cd ~/Downloads'
alias skim='open -a "Skim"'
alias des='cd ~/Desktop' 
alias dl='cd ~/Downloads'
alias icloud='cd /Users/'$USER'/Library/Mobile\ Documents/com~apple~CloudDocs'
# Lock the screen (when going AFK)
alias afk='/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend'
alias wifion='networksetup -setairportpower en0 on'
alias wifioff='networksetup -setairportpower en0 off'
# Recursively delete all .DS_Store files
alias cleandsstore="find ~/ -type f -name '*.DS_Store' -ls -delete"
# Clear DNS cache
alias cleardnscache="sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder"
# Clean up LaunchServices to remove duplicates in the "Open With" menu
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"
# Merge PDF files, Usage: `mergepdf -o output.pdf input{1,2,3}.pdf`
alias mergepdf='/System/Library/Automator/Combine\ PDF\ Pages.action/Contents/Resources/join.py'
# Show system information
alias displays="system_profiler SPDisplaysDataType"
alias cpuinfo="sysctl -n machdep.cpu.brand_string"
alias hardwareports='networksetup -listallhardwareports'
# Mute/Unmute the system volume. Plays nice with all other volume settings.
alias mute="osascript -e 'set volume output muted true'"
alias unmute="osascript -e 'set volume output muted false'"
