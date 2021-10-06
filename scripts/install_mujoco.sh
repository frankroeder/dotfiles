#!/bin/bash
# Install the MuJoCo simulator and the Python wrapper (mujoco_py) provided by OpenAI
# You have to provide the directory where to install the Mujoco and mujoco_py packages and which contains the mjkey.txt
# References:
# - install mujoco: https://www.roboti.us/index.html
# - install mujoco_py: https://github.com/openai/mujoco-py

# Define few variables
ORIGIN_DIR=$PWD

# install mujoco
MUJOCO_PATH="$HOME/.mujoco"
if [[ -d "$MUJOCO_PATH" ]]; then
  echo "mujoco directory already exists";
else
  mkdir $MUJOCO_PATH;
  cd $MUJOCO_PATH;
  # check OS
  if [[ "$OSTYPE" == "Linux" ]]; then  # LINUX
      PACKAGE="mujoco200_linux"
      sudo apt install libosmesa6-dev libgl1-mesa-glx libglfw3 patchelf;
  elif [[ "$OSTYPE" == "Darwin" ]]; then  # Mac OSX
      PACKAGE="mujoco200_macos"
  elif [[ "$OSTYPE" == "msys" ]]; then  # Windows
      PACKAGE="mujoco200_win64"
  else
      echo "This OS is not supported. Expecting a Linux, Mac OSX, or Windows system.";
      exit;
  fi
  # download package and unzip it
  wget "https://www.roboti.us/download/${PACKAGE}.zip";
  unzip "${PACKAGE}.zip";
  ln -sfv "$PACKAGE" "mujoco200";

  if [[ -f "mjkey.txt" ]]; then
    echo "mjkey exists";
  else
    # get free licence
    echo "getting free licence";
    wget "https://www.roboti.us/;mjkey.txt";
  fi
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
    echo "export MUJOCO_PY_MJPRO_PATH=${MUJOCO_PATH}/${PACKAGE}" >> $LOCAL_FILE;
    echo "export MUJOCO_PY_MUJOCO_PATH=${MUJOCO_PATH}/${PACKAGE}" >> $LOCAL_FILE;
    echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${MUJOCO_PATH}/${PACKAGE}/bin" >> $LOCAL_FILE;
    echo "export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libGLEW.so:/usr/lib/x86_64-linux-gnu/libGL.so" >> $LOCAL_FILE;
  else
    echo "# MuJoCo";
    echo "export MUJOCO_PY_MJKEY_PATH=${MUJOCO_PATH}/mjkey.txt";
    echo "export MUJOCO_PY_MJPRO_PATH=${MUJOCO_PATH}/${PACKAGE}";
    echo "export MUJOCO_PY_MUJOCO_PATH=${MUJOCO_PATH}/${PACKAGE}";
    echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${MUJOCO_PATH}/${PACKAGE}/bin";
    echo "export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libGLEW.so:/usr/lib/x86_64-linux-gnu/libGL.so";
  fi
  rm -rfv "${PACKAGE}.zip";
  # return to the original directory
  cd $ORIGIN_DIR;
fi
