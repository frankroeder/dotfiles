#!/bin/bash

main() {
  local git_username
  local git_email
  local LOCAL_GIT_CONF=$HOME/.local.gitconfig
  cd "$HOME" || exit 1

  if [ -z "$(git config --get user.email)" ]; then
      read -p "Please input your git email: " -r git_email
      echo "[user]
  email = $git_email" >> $LOCAL_GIT_CONF;
  else
    echo "Email found: $(git config --get user.email)"
  fi

  if [ -z "$(git config --get credential.helper)" ]; then
    if [[ "$OSTYPE" == "Darwin" ]]; then
      "git config --global credential.helper osxkeychain"
      echo "[credential]
    helper = osxkeychain" >> $LOCAL_GIT_CONF;
    elif [[ "$OSTYPE" == "Linux" ]]; then
      echo "[credential]
    helper = cache --timeout=3600" >> $LOCAL_GIT_CONF;
    fi
  else
    echo "Credential helper found: $(git config --get credential.helper)"
  fi
}
main;
