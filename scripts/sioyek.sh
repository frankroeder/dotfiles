#!/usr/bin/env zsh

setopt PIPE_FAIL PRINT_EXIT_VALUE ERR_RETURN SOURCE_TRACE XTRACE

if [ ! -d "$HOME/tmp/sioyek" ]; then
	git clone --recursive https://github.com/ahrm/sioyek "$HOME/tmp/sioyek"
  cd "$HOME/tmp/sioyek" || exit 1
  if [[ ! -x build_mac.sh ]]; then
		chmod +x build_mac.sh
  fi
else
  cd "$HOME/tmp/sioyek" || exit 1
  git pull
  if [[ ! -x delete_build.sh ]]; then
    chmod +x delete_build.sh
  fi
  ./delete_build.sh
fi

brew install 'qt@5' freeglut mesa harfbuzz

export PATH="/opt/homebrew/opt/qt@5/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/qt@5/lib"
export CPPFLAGS="-I/opt/homebrew/opt/qt@5/include"

MAKE_PARALLEL=8 ./build_mac.sh

mv build/sioyek.app /Applications/
sudo codesign --force --sign - --deep /Applications/sioyek.app
sudo ln -s /Applications/sioyek.app/Contents/MacOS/sioyek /usr/local/bin/sioyek
