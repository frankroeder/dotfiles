autoload -Uz compinit && compinit -C -d "${ZDOTDIR:-${HOME}}/${zcompdump_file:-.zcompdump}"

fpath=(~/.zsh/completion $fpath)

setopt AUTO_MENU          # show completion menu on a successive tab press
setopt ALWAYS_TO_END      # move cursor to the end of a completed word
setopt AUTO_LIST          # automatically list choices on ambiguous completion
setopt AUTO_PARAM_SLASH   # if completed parameter is a directory, add a trailing slash
setopt COMPLETE_IN_WORD   # complete from both ends of a word
setopt EXTENDED_GLOB      # needed for file modification glob modifiers with compinit
setopt PATH_DIRS          # perform path search even on command names with slashes
setopt GLOBDOTS           # files beginning with a . be matched without explicitly specifying the dot
setopt GLOB_COMPLETE      # do not insert all words from expansion

unsetopt MENU_COMPLETE    # do not autoselect the first completion entry
unsetopt CASE_GLOB        # makes globbing (filename generation) case-sensitive

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# forces zsh to realize new commands
zstyle ':completion:*' completer _oldlist _expand _complete _match _ignored _approximate
zstyle ':completion:*' list-colors "=*="

# group results by category
zstyle ':completion:*:matches' group yes
zstyle ':completion:*' group-name ''
zstyle ':completion:*:options' description yes
zstyle ':completion:*:options' auto-description '<%d>'
zstyle ':completion:*' format ' %F{magenta}-- %d --%f'
zstyle ':completion:*' verbose true

# completion lists that don’t fit on the screen can be scrolled
zstyle ':completion:*:default' list-prompt '%S%M matches%s'

# enable caching
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "${ZDOTDIR:-${HOME}}/.zcompcache"

# pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending

# ignores patterns
zstyle ':completion:*:*files' ignored-patterns '*?.o' '*?~' '*\#'
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

# Media Players
AUDIO_FILES='wav|mp3|ogg|flac|aif|aiff|alac|aac'
zstyle ':completion:*:*:vlc:*' file-patterns "*.(mkv|avi|wmv|mov|m4a|mpg|mpeg|mp4|$AUDIO_FILES):mp3\ files *(-/):directories"
zstyle ':completion:*:*:afplay:*' file-patterns "*.($AUDIO_FILES):mp3\ files *(-/):directories"
