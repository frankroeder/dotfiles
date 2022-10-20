#!/bin/bash
# Install the MuJoCo simulator and the Python wrapper (mujoco_py) provided by OpenAI
# You have to provide the directory where to install the Mujoco and mujoco_py packages and which contains the mjkey.txt
# References:
# - install mujoco: https://www.roboti.us/index.html
# - install mujoco_py: https://github.com/openai/mujoco-py

ORIGIN_DIR=$PWD
VERSION="2.1.1"

# install mujoco
MUJOCO_PATH="$HOME/.mujoco"
if [[ -d "$MUJOCO_PATH" ]]; then
  echo "mujoco directory already exists";
else
  mkdir $MUJOCO_PATH;
  cd $MUJOCO_PATH;
  # check OS
  if [[ "$OSTYPE" == "Linux" ]]; then  # LINUX
      ASSET="${VERSION}-linux-x86_64"
      ENDING=".tar.gz"
      sudo apt install libosmesa6-dev libgl1-mesa-glx libglfw3 patchelf;
  elif [[ "$OSTYPE" == "Darwin" ]]; then  # macos ARM and Intel
      ASSET="${VERSION}-macos-universal2"
      ENDING=".dmg"
  else
      echo "This OS is not supported. Expecting Linux or macOS";
      exit 1;
  fi
  PACKAGE="${ASSET}${ENDING}"
  URI="https://github.com/deepmind/mujoco/releases/download/$VERSION/mujoco-${PACKAGE}"
  echo "Downloading ...";
  curl -LO $URI;
  CURRENT_CHECKSUM=$(openssl sha256 "${PACKAGE}" | awk {'print $2'});
  EXPECTED_CHECKSUM=$(curl -L "$URI.sha256" | awk {'print $1'});
  if [[ $CURRENT_CHECKSUM == $EXPECTED_CHECKSUM ]]; then
    printf '%s matches %s\n' "$CURRENT_CHECKSUM" "$EXPECTED_CHECKSUM";
  else
    printf '[!] %s is not matching: %s\n' "$CURRENT_CHECKSUM" "$EXPECTED_CHECKSUM";
    exit 1;
  fi
  if [[ "$OSTYPE" == "Linux" ]]; then
    tar xf "${PACKAGE}"
  elif [[ "$OSTYPE" == "Darwin" ]]; then
    VOLUME=`hdiutil attach ${PACKAGE} | grep Volumes | awk '{print $3}'`
    cp -rf $VOLUME/*.app /Applications
    hdiutil detach $VOLUME
    mkdir -p $HOME/.mujoco/mujoco210
    ln -sf /Applications/MuJoCo.app/Contents/Frameworks/MuJoCo.framework/Versions/Current/Headers/ $HOME/.mujoco/mujoco210/include
    mkdir -p $HOME/.mujoco/mujoco210/bin
    ln -sf /Applications/MuJoCo.app/Contents/Frameworks/MuJoCo.framework/Versions/Current/libmujoco.2.1.1.dylib $HOME/.mujoco/mujoco210/bin/libmujoco210.dylib
    ln -sf /Applications/MuJoCo.app/Contents/Frameworks/MuJoCo.framework/Versions/Current/libmujoco.2.1.1.dylib /usr/local/lib/
    # glfw
    conda install -y glfw
    rm -rfiv $CONDA_PREFIX/lib/python3.*/site-packages/glfw/libglfw.3.dylib
    ln -sf $CONDA_PREFIX/lib/libglfw.3.dylib $HOME/.mujoco/mujoco210/bin
    if [ $(uname -m) =~ "arm" ]; then
      if [ ! -x "$(command -v gcc-12)" ]; then
        brew install gcc
      fi
      export CC=/opt/homebrew/bin/gcc-12
    fi
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
    echo "export MUJOCO_PY_MUJOCO_PATH=${MUJOCO_PATH}/${VERSION}" >> $LOCAL_FILE;
    echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${MUJOCO_PATH}/${VERSION}/bin" >> $LOCAL_FILE;
    echo "export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libGLEW.so:/usr/lib/x86_64-linux-gnu/libGL.so" >> $LOCAL_FILE;
  else
    echo "# MuJoCo";
    echo "export MUJOCO_PY_MUJOCO_PATH=${MUJOCO_PATH}/${VERSION}";
    echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${MUJOCO_PATH}/${VERSION}/bin";
    echo "export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libGLEW.so:/usr/lib/x86_64-linux-gnu/libGL.so";
  fi
  rm -rf "${PACKAGE}";
  cd $ORIGIN_DIR;
  pip install mujoco-py && python -c 'import mujoco_py'
fi
