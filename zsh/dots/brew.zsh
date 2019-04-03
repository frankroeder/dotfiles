export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_CASK_OPTS=--require-sha

if type brew &>/dev/null; then
  fpath=($fpath $(brew --prefix)/share/zsh/site-functions)
fi

if type gcloud &>/dev/null; then
  local GCPREFIX='/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk'
  source $GCPREFIX'/path.zsh.inc'
  source $GCPREFIX'/completion.zsh.inc'
fi

if type terraform &>/dev/null; then
  TF_VERSION=$(terraform --version | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/')
  complete -o nospace -C \
    "$(brew --prefix)/Cellar/terraform/$TF_VERSION/bin/terraform" terraform
fi
