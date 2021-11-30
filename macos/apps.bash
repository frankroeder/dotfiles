################################################################################
# Application Settings                                                         #
################################################################################

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# GPG Suite
# Disable signing emails by default
defaults write ~/Library/Preferences/org.gpgtools.gpgmail SignNewEmailsByDefault -bool false
defaults write ~/Library/Preferences/org.gpgtools.gpgmail EncryptNewEmailsByDefault -bool false

# VLC media player
# Enable checking for updates automatically.
defaults write org.videolan.vlc SUEnableAutomaticChecks -bool true

# Disable checking online for album art and metadata.
defaults write org.videolan.vlc SUSendProfileInfo -bool false

# Skim
# turn off auto reload dialog, default to auto reload
defaults write -app Skim SKAutoReloadFileUpdate -boolean true
defaults write -app Skim SKAutoCheckFileUpdate -bool true
# Image Smoothing
defaults write -app Skim SKInterpolationQuality  -int 2
defaults write -app Skim SKShowStatusBar -bool true
defaults write -app Skim SUAutomaticallyUpdate  -bool true
defaults write -app Skim AppleWindowTabbingMode -string "manual"

# Preview
# Do not show sidebar
defaults write com.apple.Preview PVSidebarViewModeForNewDocuments -boolean false

# Rectangle
defaults write com.knollsoft.Rectangle SUEnableAutomaticChecks -bool true
defaults write com.knollsoft.Rectangle launchOnLogin -bool true
defaults write com.knollsoft.Rectangle alternateDefaultShortcuts -bool true
defaults write com.knollsoft.Rectangle gapSize -int 10
# subsequentExecutionMode accepts the following values:
# 0: halves to thirds Spectacle behavior (box unchecked)
# 1: cycle displays (box checked) for left/right actions
# 2: disabled
# 3: cycle displays for left/right actions, halves to thirds for the rest (old Rectangle behavior)
# 4: repeat same action on next display
defaults write com.knollsoft.Rectangle subsequentExecutionMode -int 1
defaults write com.knollsoft.Rectangle moveCursorAcrossDisplays -bool true

# Apple Music
defaults write com.apple.Music showStatusBar -bool true
defaults write com.apple.Music losslessEnabled -bool true
defaults write com.apple.Music encoderName -string "AIFF Encoder"
defaults write com.apple.Music preferredStreamPlaybackAudioQuality -int 15
defaults write com.apple.Music preferredDownloadAudioQuality -int 15

# zoom.us
defaults write ZoomChat ZoomEnterMaxWndWhenViewShare -bool false
defaults write ZoomChat ZMEnableShowUserName -bool true
