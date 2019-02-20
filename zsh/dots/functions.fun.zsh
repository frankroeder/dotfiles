# Functions for fun
# ------------------------------------------------------------------------------
 
fliptable() {
  echo -e "\n\n\t（╯°□°）╯︵ ┻━┻\n\n";
}

facepalm() {
  echo -e "\n\n\t(－‸ლ)\n\n";
}

# matrix: Function to Enable Matrix Effect in the terminal
matrix() {
	echo -e "\\e[1;40m" ; clear ; while :; do echo $LINES $COLUMNS $(( $RANDOM % $COLUMNS)) $(( $RANDOM % 72 )) ;
  sleep 0.05; done|awk '{ letters="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()"; c=$4; letter=substr(letters,c,1);a[$3]=0;for (x in a) {o=a[x];a[x]=a[x]+1; printf "\033[%s;%sH\033[2;32m%s",o,x,letter; printf "\033[%s;%sH\033[1;37m%s\033[0;0H",a[x],x,letter;if (a[x] >= $1) { a[x]=0; } }}'
}

parrot() {
  curl parrot.live
}


sound() {
  file=$(ls /System/Library/Sounds/ | sort -R | head -1)
  afplay /System/Library/Sounds/$file
}

lookbusy() {
  cat /dev/urandom | hexdump -C | grep --color "ca fe"
}
