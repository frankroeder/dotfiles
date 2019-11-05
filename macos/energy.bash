# Set standby delay to 24 hours (default is 1 hour)
sudo pmset -a standbydelay 86400

# Restart automatically if the computer freezes
sudo systemsetup -setrestartfreeze on

# Sleep the display after 5 minutes
sudo pmset -a displaysleep 5

# Set machine sleep to 15 minutes on battery
sudo pmset -b sleep 15

# Never go into computer sleep mode
sudo systemsetup -setcomputersleep Off > /dev/null

# Menu bar: show battery percentage
defaults write com.apple.menuextra.battery ShowPercent -bool true

# Hibernation mode
# 0: Disable hibernation (speeds up entering sleep mode)
# 3: Copy RAM to disk so the system state can still be restored in case of a
#    power failure.
sudo pmset -a hibernatemode 0

# Enable lid wakeup
sudo pmset -a lidwake 1

# Restart automatically on power loss
sudo pmset -a autorestart 1

# Disable machine sleep while charging
sudo pmset -c sleep 0
