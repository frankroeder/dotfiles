################################################################################
# Screen                                                                       #
################################################################################

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 5

# Save screenshots to the desktop
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
defaults write NSGlobalDomain AppleFontSmoothing -int 1
