# install gazebo
curl -sSL https://get.gazebosim.org | sh

# install ros noetic
# http://wiki.ros.org/noetic/Installation/Ubuntu
sudo apt-get update -y
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
sudo apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
sudo apt update -y
sudo apt install ros-noetic-desktop python3-rosdep -y
sudo rosdep init
rosdep update

# install coppeliasim
COPPELIA_VERSION="CoppeliaSim_Edu_V4_1_0_Ubuntu20_04"
PKG="$COPPELIA_VERSION.tar.xz"
curl -L https://www.coppeliarobotics.com/files/$PKG > "$HOME/$PKG"
tar -xJfv $HOME/$PKG -C $HOME/
rm -rfv $HOME/$PKG

echo "export COPPELIASIM_ROOT=$HOME/$COPPELIA_VERSION"'
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$COPPELIASIM_ROOT
export QT_QPA_PLATFORM_PLUGIN_PATH=$COPPELIASIM_ROOT
# ROS
if [ -f /opt/ros/noetic/setup.zsh ]
then
  source /opt/ros/noetic/setup.zsh
fi

export ROS_HOSTNAME=localhost
export ROS_MASTER_URI=http://localhost:11311
export ROS_PYTHON_VERSION=3
' >> $HOME/.local.zsh
