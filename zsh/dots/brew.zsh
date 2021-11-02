! [ $commands[brew] ] && return

export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_CASK_OPTS=--require-sha
export HOMEBREW_INSTALL_BADGE="🍵"

(( $+commands[brew] )) && {
  fpath=($HOMEBREW_PREFIX/share/zsh/site-functions $fpath)
}

(( $+commands[gcloud] )) && {
  GCPREFIX="$HOMEBREW_PREFIX/Caskroom/google-cloud-sdk/latest/google-cloud-sdk"
  [ -f $GCPREFIX/path.zsh.inc ] && source $GCPREFIX/path.zsh.inc
  [ -f $GCPREFIX/completion.zsh.inc ] && source $GCPREFIX/completion.zsh.inc
}

(( $+commands[terraform] )) && {
  TF_VERSION=${$(terraform --version)[2]:1}
  complete -o nospace -C \
    "$HOMEBREW_PREFIX/Cellar/terraform/$TF_VERSION/bin/terraform" terraform
}

[[ $ARCHITECTURE == 'arm64' ]] && {
  alias abrew='/opt/homebrew/bin/brew'
}
