#!/bin/bash
# Install the MuJoCo simulator and the Python wrapper (mujoco_py) provided by OpenAI
# You have to provide the directory where to install the Mujoco and mujoco_py packages and which contains the mjkey.txt
# References:
# - install mujoco: https://www.roboti.us/index.html
# - install mujoco_py: https://github.com/openai/mujoco-py

ORIGIN_DIR=$PWD
VERSION="mujoco210"

# install mujoco
MUJOCO_PATH="$HOME/.mujoco"
if [[ -d "$MUJOCO_PATH" ]]; then
  echo "mujoco directory already exists";
else
  mkdir $MUJOCO_PATH;
  cd $MUJOCO_PATH;
  # check OS
  if [[ "$OSTYPE" == "Linux" ]]; then  # LINUX
      PACKAGE="$VERSION-linux-x86_64"
      sudo apt install libosmesa6-dev libgl1-mesa-glx libglfw3 patchelf;
  elif [[ "$OSTYPE" == "Darwin" ]]; then  # Mac OSX
      PACKAGE="$VERSION-macos-x86_64"
  else
      echo "This OS is not supported. Expecting Linux or macOS";
      exit;
  fi
  URI="https://www.mujoco.org/download/${PACKAGE}.tar.gz";
  # download package and unzip it
  echo "Downloading ...";
  curl -LO $URI;
  CURRENT_CHECKSUM=$(openssl sha256 "${PACKAGE}.tar.gz" | awk {'print $2'});
  EXPECTED_CHECKSUM=$(curl -L "$URI.sha256" | awk {'print $1'});
  if [[ $CURRENT_CHECKSUM == $EXPECTED_CHECKSUM ]]; then
    printf '%s matches %s\n' "$CURRENT_CHECKSUM" "$EXPECTED_CHECKSUM";
  else
    printf '[!] %s is not matching: %s\n' "$CURRENT_CHECKSUM" "$EXPECTED_CHECKSUM";
    exit;
  fi
  tar xf "${PACKAGE}.tar.gz"

  # obtain free licence
  curl -LO "https://www.roboti.us/file/mjkey.txt";

  # write variables to export
  if [[ -n "$ZSH_VERSION" ]]; then
    LOCAL_FILE="$HOME/.local.zsh";
  else
    LOCAL_FILE="$HOME/.bashrc";
  fi
  if [[ -f $LOCAL_FILE ]]; then
    echo "" >> $LOCAL_FILE;
    echo "# MuJoCo" >> $LOCAL_FILE;
    echo "export MUJOCO_PY_MJKEY_PATH=${MUJOCO_PATH}/mjkey.txt" >> $LOCAL_FILE;
    echo "export MUJOCO_PY_MJPRO_PATH=${MUJOCO_PATH}/${VERSION}" >> $LOCAL_FILE;
    echo "export MUJOCO_PY_MUJOCO_PATH=${MUJOCO_PATH}/${VERSION}" >> $LOCAL_FILE;
    echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${MUJOCO_PATH}/${VERSION}/bin" >> $LOCAL_FILE;
    echo "export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libGLEW.so:/usr/lib/x86_64-linux-gnu/libGL.so" >> $LOCAL_FILE;
  else
    echo "# MuJoCo";
    echo "export MUJOCO_PY_MJKEY_PATH=${MUJOCO_PATH}/mjkey.txt";
    echo "export MUJOCO_PY_MJPRO_PATH=${MUJOCO_PATH}/${VERSION}";
    echo "export MUJOCO_PY_MUJOCO_PATH=${MUJOCO_PATH}/${VERSION}";
    echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${MUJOCO_PATH}/${VERSION}/bin";
    echo "export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libGLEW.so:/usr/lib/x86_64-linux-gnu/libGL.so";
  fi
  rm -rf "${PACKAGE}.tar.gz";
  cd $ORIGIN_DIR;
fi
