export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_CASK_OPTS=--require-sha

(( $+commands[brew] )) && {
  fpath=(/usr/local/share/zsh/site-functions $fpath)
}

(( $+commands[gcloud] )) && {
  GCPREFIX="/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk"
  [ -f $GCPREFIX/path.zsh.inc ] && source $GCPREFIX/path.zsh.inc
  [ -f $GCPREFIX/completion.zsh.inc ] && source $GCPREFIX/completion.zsh.inc
}

(( $+commands[terraform] )) && {
  TF_VERSION=${$(terraform --version)[2]:1}
  complete -o nospace -C \
    "/usr/local/Cellar/terraform/$TF_VERSION/bin/terraform" terraform
}
