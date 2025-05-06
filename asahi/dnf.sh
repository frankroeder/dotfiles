dnf_update() {
  sudo dnf upgrade && dnf update
}

install_default() {
  dnf_update;
  local PKGS="
    bash
    cmake
    curl
    ffmpeg
    git
    htop
    imagemagick
    iputils-ping
    jq
    lsof
    make
    man
    python3-dev
    python3-pip
    ripgrep
    sudo
    tmux
    tree
    wget
    zsh
  "
  sudo dnf install $PKGS -y;
}

install_default;
