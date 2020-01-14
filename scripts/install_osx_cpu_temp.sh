#!/usr/bin/env bash

ping -c 1 www.google.com
if [ $? -eq 0 ]; then
  git clone https://github.com/lavoiesl/osx-cpu-temp ~/.osx-cpu-temp
  cd ~/.osx-cpu-temp
  sudo make install
fi
