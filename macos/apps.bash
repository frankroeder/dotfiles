################################################################################
# Application Settings                                                         #
################################################################################

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# Preview
# Do not show sidebar
defaults write com.apple.Preview PVSidebarViewModeForNewDocuments -boolean false

# Apple Music
defaults write com.apple.Music showStatusBar -bool true
defaults write com.apple.Music losslessEnabled -bool true
defaults write com.apple.Music encoderName -string "AIFF Encoder"
defaults write com.apple.Music preferredStreamPlaybackAudioQuality -int 15
defaults write com.apple.Music preferredDownloadAudioQuality -int 15

# zoom.us
defaults write ZoomChat ZoomEnterMaxWndWhenViewShare -bool false
defaults write ZoomChat ZMEnableShowUserName -bool true
