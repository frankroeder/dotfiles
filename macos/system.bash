# Disable the sound effects on boot
sudo nvram SystemAudioVolume=%00

# Check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -bool true

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool true

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true

# Crash reporter
# 'none' or 'crashreport'
defaults write com.apple.CrashReporter DialogType -string 'crashreport'

# crash reporter as pop-up
defaults write com.apple.CrashReporter UseUNC 1

# Disable Dashboard
defaults write com.apple.dashboard mcx-disabled -bool true

# Don’t show Dashboard as a space
defaults write com.apple.dock dashboard-in-overlay -bool true

# Show Time Connected in VPN menubar item
defaults write com.apple.networkConnect VPNShowTime -bool true

# Show Status When Connecting in VPN menubar item
defaults write com.apple.networkConnect VPNShowStatus -bool true

# Allow signed apps
sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -bool true

# Stealth mode
sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -bool true

# Disable Siri
defaults write com.apple.assistant.support "Assistant Enabled" -bool false

# Disable flashing the screen when an alert sound occurs (accessibility)
defaults write NSGlobalDomain com.apple.sound.beep.flash -bool false

# Disable audio feedback when volume is changed
defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool false

# Disable interface sound effects
defaults write NSGlobalDomain com.apple.sound..uiaudio.enabled -bool false

# Display login window as: Name and password
sudo defaults write /Library/Preferences/com.apple.loginwindow "SHOWFULLNAME" -bool false

# Allow guests to login to this computer
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

# Disable remote control infrared receiver.
sudo defaults write /Library/Preferences/com.apple.driver.AppleIRController DeviceEnabled -bool false

# Limit ad tracking
defaults write com.apple.AdLib forceLimitAdTracking -bool true
