# Disable the sound effects on boot
sudo nvram SystemAudioVolume=" "

# Check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -bool true

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool true

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true

# Disable the crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"

# crash reporter as pop-up
defaults write com.apple.CrashReporter UseUNC 1

# Disable Dashboard
defaults write com.apple.dashboard mcx-disabled -bool true

# Don’t show Dashboard as a space
defaults write com.apple.dock dashboard-in-overlay -bool true
