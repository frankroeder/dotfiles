################################################################################
# Screen and visuals                                                           #
################################################################################

# Disable menu bar transparency
defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -bool true
defaults write com.apple.screensaver askForPasswordDelay -int 5

# Show screensaver with clock
defaults -currentHost write com.apple.screensaver showClock -bool true

# Save screenshots to custom folder
defaults write com.apple.screencapture location -string "${HOME}/screens"

# Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "png"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Change row layout of LaunchPad
defaults write com.apple.dock springboard-rows -int 5
defaults write com.apple.dock ResetLaunchPad -bool true

# Change banner display time (in seconds, default:5)
defaults write com.apple.notificationcenterui bannerTime 3

# Enable subpixel font rendering on non-Apple LCDs
# Options: 1 for light smoothing up to 3 for strong smoothing
defaults write NSGlobalDomain AppleFontSmoothing -int 1

# Disable automatic brightness adjustment
sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor \
  "Automatic Display Enabled" -bool false

# Scrollbars visible when scrolling
defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# Increase window resize speed for Cocoa applications
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Set sidebar icon size to medium
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# Disable opening and closing window animations
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

# Menubar items
defaults write com.apple.systemuiserver menuExtras -array \
  "/System/Library/CoreServices/Menu Extras/Clock.menu" \
  "/System/Library/CoreServices/Menu Extras/Battery.menu" \
  "/System/Library/CoreServices/Menu Extras/AirPort.menu" \
  "/System/Library/CoreServices/Menu Extras/Bluetooth.menu" \
  "/System/Library/CoreServices/Menu Extras/Volume.menu" \
  "/System/Library/CoreServices/Menu Extras/VPN.menu"
