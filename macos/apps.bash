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

# Disable signing emails by default
defaults write ~/Library/Preferences/org.gpgtools.gpgmail SignNewEmailsByDefault -bool true
defaults write ~/Library/Preferences/org.gpgtools.gpgmail EncryptNewEmailsByDefault -bool false
