################################################################################
# Application Settings                                                         #
################################################################################

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# GPG Suite
# Disable signing emails by default
defaults write ~/Library/Preferences/org.gpgtools.gpgmail SignNewEmailsByDefault -bool true
defaults write ~/Library/Preferences/org.gpgtools.gpgmail EncryptNewEmailsByDefault -bool false

# VLC media player
# Enable checking for updates automatically.
defaults write org.videolan.vlc SUEnableAutomaticChecks -bool true

# Disable checking online for album art and metadata.
defaults write org.videolan.vlc SUSendProfileInfo -bool true

# Skim
# turn off auto reload dialog, default to auto reload
defaults write -app Skim SKAutoReloadFileUpdate -boolean true

# Preview
# Do not show sidebar
defaults write com.apple.Preview PVSidebarViewModeForNewDocuments -boolean false
