#!/usr/bin/env bash

if [[ $ARCHITECTURE == 'x86_64' ]]; then
  ping -c 1 www.google.com
  if [ $? -eq 0 ]; then
    SRC_DIR="$HOME/tmp/osx-cpu-temp"
    if [[ -d $SRC_DIR ]]; then
      cd $SRC_DIR
      git pull
    else
      git clone https://github.com/lavoiesl/osx-cpu-temp $SRC_DIR
      cd $SRC_DIR
    fi
    sudo make install
  fi
fi
