export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_CASK_OPTS=--require-sha

if (( $+commands[brew] )); then
  fpath=($(brew --prefix)/share/zsh/site-functions $fpath)
fi

if (( $+commands[gcloud] )); then
  local GCPREFIX="/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk"
  path=("$GCPREFIX/path.zsh.inc" $path)
  fpath=("$GCPREFIX/completion.zsh.inc" $fpath)
fi

if (( $+commands[terraform] )); then
  TF_VERSION=$(terraform --version | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/')
  complete -o nospace -C \
    "$(brew --prefix)/Cellar/terraform/$TF_VERSION/bin/terraform" terraform
fi
