################################################################################
# Application Settings                                                         #
################################################################################

# turn off auto reload dialog, default to auto reload
defaults write -app Skim SKAutoReloadFileUpdate -boolean true

# Disable iTunes track notifications in the Dock
defaults write com.apple.dock itunes-notifications -bool false

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# Turn on automatic updates.
defaults write com.divisiblebyzero.Spectacle SUEnableAutomaticChecks -bool true

# Show Spectacle in the status menu
defaults write com.divisiblebyzero.Spectacle StatusItemEnabled -bool false
