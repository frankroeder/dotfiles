fpath=(~/.zsh/completion $fpath)

unsetopt MENU_COMPLETE    # do not autoselect the first completion entry
unsetopt FLOW_CONTROL     # disable start/stop characters in shell editor
unsetopt CASE_GLOB        # makes globbing (filename generation) case-sensitive
unsetopt NOMATCH          # Allow [ or ]

setopt AUTO_MENU          # show completion menu on a successive tab press
setopt ALWAYS_TO_END      # move cursor to the end of a completed word
setopt AUTO_LIST          # automatically list choices on ambiguous completion
setopt AUTO_PARAM_SLASH   # if completed parameter is a directory, add a trailing slash
setopt COMPLETE_IN_WORD   # complete from both ends of a word
setopt EXTENDED_GLOB      # needed for file modification glob modifiers with compinit
setopt PATH_DIRS          # perform path search even on command names with slashes
setopt GLOBDOTS           # files beginning with a . be matched without explicitly specifying the dot
setopt MULTIOS
setopt IGNORE_EOF         # prevent accidental C-d from exiting shell
setopt GLOB_COMPLETE      # do not insert all words from expansion


zstyle ':completion:*:*:*:*:*' menu select

if [[ "$CASE_SENSITIVE" = true ]]; then
  zstyle ':completion:*' matcher-list 'r:|=*' 'l:|=* r:|=*'
else
  zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
fi
# forces zsh to realize new commands
zstyle ':completion:*' completer _oldlist _expand _complete _match _ignored _approximate
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,%cpu,cputime,user,comm -w -w"

# Group results by category
zstyle ':completion:*:matches' group yes
zstyle ':completion:*' group-name ''
zstyle ':completion:*:options' description yes
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{magenta}-- %d --%f'
zstyle ':completion:*' verbose yes


# enable caching to make completion for commands such as dpkg and apt usable
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "${ZDOTDIR:-$HOME}/.zcompcache"

# pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending
#
# fuzzy match mistyped completions
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# ignores unavailable commands
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec)|prompt_*)'

# separate man page sections
zstyle ':completion:*:manuals' separate-sections true

# completion element sorting
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# ignore multiple entries
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
zstyle ':completion:*:rm:*' file-patterns '*:all-files'

# Don't complete uninteresting users
zstyle ':completion:*:*:*:users' ignored-patterns \
        adm amanda apache at avahi avahi-autoipd beaglidx bin cacti canna \
        clamav daemon dbus distcache dnsmasq dovecot fax ftp games gdm \
        gkrellmd gopher hacluster haldaemon halt hsqldb ident junkbust kdm \
        ldap lp mail mailman mailnull man messagebus  mldonkey mysql nagios \
        named netdump news nfsnobody nobody nscd ntp nut nx obsrun openvpn \
        operator pcap polkitd postfix postgres privoxy pulse pvm quagga radvd \
        rpc rpcuser rpm rtkit scard shutdown squid sshd statd svn sync tftp \
        usbmux uucp vcsa wwwrun xfs '_*'
