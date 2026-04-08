autoload -U colors && colors

for COLOR in RED GREEN YELLOW BLUE MAGENTA CYAN BLACK WHITE; do
  eval $COLOR='$fg_no_bold[${(L)COLOR}]'
  eval BOLD_$COLOR='$fg_bold[${(L)COLOR}]'
done
eval RESET='$reset_color'

export LS_COLORS='rs=0:di=01;38;5;12:ln=01;38;5;14:mh=00:pi=38;5;3:so=01;38;5;13:do=01;38;5;13:bd=38;5;11:cd=38;5;11:or=38;5;9:mi=38;5;15;48;5;9:su=38;5;15;48;5;9:sg=38;5;0;48;5;11:ca=00:tw=38;5;0;48;5;10:ow=38;5;0;48;5;12:st=38;5;15;48;5;12:ex=01;38;5;10:*.7z=01;38;5;9:*.ace=01;38;5;9:*.alz=01;38;5;9:*.apk=01;38;5;9:*.arc=01;38;5;9:*.arj=01;38;5;9:*.bz=01;38;5;9:*.bz2=01;38;5;9:*.cab=01;38;5;9:*.cpio=01;38;5;9:*.crate=01;38;5;9:*.deb=01;38;5;9:*.drpm=01;38;5;9:*.dwm=01;38;5;9:*.dz=01;38;5;9:*.ear=01;38;5;9:*.egg=01;38;5;9:*.esd=01;38;5;9:*.gz=01;38;5;9:*.jar=01;38;5;9:*.lha=01;38;5;9:*.lrz=01;38;5;9:*.lz=01;38;5;9:*.lz4=01;38;5;9:*.lzh=01;38;5;9:*.lzma=01;38;5;9:*.lzo=01;38;5;9:*.pyz=01;38;5;9:*.rar=01;38;5;9:*.rpm=01;38;5;9:*.rz=01;38;5;9:*.sar=01;38;5;9:*.swm=01;38;5;9:*.t7z=01;38;5;9:*.tar=01;38;5;9:*.taz=01;38;5;9:*.tbz=01;38;5;9:*.tbz2=01;38;5;9:*.tgz=01;38;5;9:*.tlz=01;38;5;9:*.txz=01;38;5;9:*.tz=01;38;5;9:*.tzo=01;38;5;9:*.tzst=01;38;5;9:*.udeb=01;38;5;9:*.war=01;38;5;9:*.whl=01;38;5;9:*.wim=01;38;5;9:*.xz=01;38;5;9:*.z=01;38;5;9:*.zip=01;38;5;9:*.zoo=01;38;5;9:*.zst=01;38;5;9:*.avif=01;38;5;13:*.jpg=01;38;5;13:*.jpeg=01;38;5;13:*.mjpg=01;38;5;13:*.mjpeg=01;38;5;13:*.gif=01;38;5;13:*.bmp=01;38;5;13:*.pbm=01;38;5;13:*.pgm=01;38;5;13:*.ppm=01;38;5;13:*.tga=01;38;5;13:*.xbm=01;38;5;13:*.xpm=01;38;5;13:*.tif=01;38;5;13:*.tiff=01;38;5;13:*.png=01;38;5;13:*.svg=01;38;5;13:*.svgz=01;38;5;13:*.mng=01;38;5;13:*.pcx=01;38;5;13:*.mov=01;38;5;13:*.mpg=01;38;5;13:*.mpeg=01;38;5;13:*.m2v=01;38;5;13:*.mkv=01;38;5;13:*.webm=01;38;5;13:*.webp=01;38;5;13:*.ogm=01;38;5;13:*.mp4=01;38;5;13:*.m4v=01;38;5;13:*.mp4v=01;38;5;13:*.vob=01;38;5;13:*.qt=01;38;5;13:*.nuv=01;38;5;13:*.wmv=01;38;5;13:*.asf=01;38;5;13:*.rm=01;38;5;13:*.rmvb=01;38;5;13:*.flc=01;38;5;13:*.avi=01;38;5;13:*.fli=01;38;5;13:*.flv=01;38;5;13:*.gl=01;38;5;13:*.dl=01;38;5;13:*.xcf=01;38;5;13:*.xwd=01;38;5;13:*.yuv=01;38;5;13:*.cgm=01;38;5;13:*.emf=01;38;5;13:*.ogv=01;38;5;13:*.ogx=01;38;5;13:*.aac=01;38;5;14:*.au=01;38;5;14:*.flac=01;38;5;14:*.m4a=01;38;5;14:*.mid=01;38;5;14:*.midi=01;38;5;14:*.mka=01;38;5;14:*.mp3=01;38;5;14:*.mpc=01;38;5;14:*.ogg=01;38;5;14:*.ra=01;38;5;14:*.wav=01;38;5;14:*.oga=01;38;5;14:*.opus=01;38;5;14:*.spx=01;38;5;14:*.xspf=01;38;5;14:*~=38;5;8:*#=38;5;8:*.bak=38;5;8:*.crdownload=38;5;8:*.dpkg-dist=38;5;8:*.dpkg-new=38;5;8:*.dpkg-old=38;5;8:*.dpkg-tmp=38;5;8:*.old=38;5;8:*.orig=38;5;8:*.part=38;5;8:*.rej=38;5;8:*.rpmnew=38;5;8:*.rpmorig=38;5;8:*.rpmsave=38;5;8:*.swp=38;5;8:*.tmp=38;5;8:*.ucf-dist=38;5;8:*.ucf-new=38;5;8:*.ucf-old=38;5;8:'
export GREP_COLORS='ms=01;38;5;0;48;5;12:mc=01;38;5;0;48;5;12:sl=38;5;8:cx=0:fn=38;5;12:ln=38;5;8:bn=38;5;11:se=38;5;13'
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[default]='fg=7'
ZSH_HIGHLIGHT_STYLES[command]='fg=12'
ZSH_HIGHLIGHT_STYLES[alias]='fg=12'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=14'
ZSH_HIGHLIGHT_STYLES[function]='fg=14'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=9'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=8'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=12'
ZSH_HIGHLIGHT_STYLES[path]='fg=6,underline'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=8'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=13'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=11'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=11'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=10'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=10'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=10'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=10'
ZSH_HIGHLIGHT_STYLES[comment]='fg=8'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=13'

export CLICOLOR=1
