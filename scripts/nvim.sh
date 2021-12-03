#!/usr/bin/env bash

install_binary(){
  # get prebuild binary release
  DEST="$HOME/bin/nvim"
  cd $HOME/tmp
  # RELEASE='nightly'
  RELEASE='v0.6.0'
  URL="https://github.com/neovim/neovim/releases/download/$RELEASE/nvim.appimage"
  curl -LO  $URL
  CURRENT_CHECKSUM=$(openssl sha256 "nvim.appimage" | awk {'print $2'});
  EXPECTED_CHECKSUM=$(curl -L "$URL.sha256sum" | awk {'print $1'});
  if [[ $CURRENT_CHECKSUM == $EXPECTED_CHECKSUM ]]; then
    printf '%s matches %s\n' "$CURRENT_CHECKSUM" "$EXPECTED_CHECKSUM";
  else
    printf '[!] %s is not matching: %s\n' "$CURRENT_CHECKSUM" "$EXPECTED_CHECKSUM";
    exit;
  fi

  chmod u+x nvim.appimage
  # redirect stdout to /dev/null
  ./nvim.appimage --appimage-extract > /dev/null
  ln -sfv $HOME/tmp/squashfs-root/AppRun $DEST
}

install_from_src() {
  # build from source
  sudo apt-get install -y ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip curl doxygen

  SRC_DIR="$HOME/tmp/neovim"
  if [[ -d $SRC_DIR ]]; then
    cd $SRC_DIR;
    git pull;
  else
    git clone https://github.com/neovim/neovim.git $SRC_DIR;
    cd $SRC_DIR;
  fi
  make -j4
  git checkout stable
  sudo make install
  make clean
}

main() {
  case $1 in
    "binary")
      echo "Installing neovim binary release";
      install_binary;;
    "src")
      echo "Installing neovim from source";
      install_from_src;;
    *)
      echo "No valid option found";;
  esac
}
main "$@";
