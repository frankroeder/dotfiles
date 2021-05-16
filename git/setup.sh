#!/bin/bash

main() {
  local git_username
  local git_email
  cd $HOME;
  if [ -z "$(git config --get user.email)" ]; then
      read -p "Please input your git email? " -r git_email
      echo "[user]
  email = $git_email" >> $HOME/.local.gitconfig;
  else
    echo "Email found: $(git config --get user.email)"
  fi
}
main;
