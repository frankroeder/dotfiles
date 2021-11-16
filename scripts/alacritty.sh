#!/usr/bin/env bash

ping -c 1 www.google.com
if [ $? -eq 0 ]; then
  if ! hash rustup 2>/dev/null; then
    # install rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --target stable
  fi

  SRC_DIR="$HOME/tmp/alacritty"
  if [[ -d $SRC_DIR ]]; then
    cd $SRC_DIR
    git pull
  else
    git clone https://github.com/alacritty/alacritty.git $SRC_DIR;
    cd $SRC_DIR
  fi

  rustup update;
  if [[ $ARCHITECTURE == 'arm64' ]]; then
    rustup target add x86_64-apple-darwin;
    rustup target add aarch64-apple-darwin;
    cargo check --target=x86_64-apple-darwin;
    cargo check --target=aarch64-apple-darwin;
    make dmg-universal;
  else
    make app;
  fi
  cp -r target/release/osx/Alacritty.app /Applications/;

  # install manual page
  gzip -c extra/alacritty.man | sudo tee /usr/local/share/man/man1/alacritty.1.gz > /dev/null
  # install shell completions
  cp extra/completions/_alacritty ${ZDOTDIR:-$HOME}/.zsh/completion
fi
