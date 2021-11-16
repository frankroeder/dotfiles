################################################################################
# Keyboard, Input & Trackpad                                                   #
################################################################################

# Enable full keyboard access (e.g. enable tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Disable automatic capitalization as it’s annoying when typing code
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic period substitution as it’s annoying when typing code
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Set a fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 3
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Automatically illuminate built-in MacBook keyboard in low light
defaults write com.apple.BezelServices kDim -bool true

# Turn off keyboard illumination when computer is not used for 5 minutes
defaults write com.apple.BezelServices kDimTime -int 30

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Enable tap to click
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -bool true

# Disable automatic keyboard brightness
sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor \
  "Automatic Keyboard Enabled" -bool false

# Enable natural scrolling
defaults write -g com.apple.swipescrolldirection -bool true

# Haptic feedback
# 0: Light
# 1: Medium
# 2: Firm
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 1
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 1

# Set Trackpad speed
defaults write -g com.apple.mouse.scaling 3.0

# Disable shake to locate mouse pointer
defaults write ~/Library/Preferences/.GlobalPreferences CGDisableCursorLocationMagnification -bool true

# Silent clicking
defaults write com.apple.AppleMultitouchTrackpad ActuationStrength -int 0

# Force Click and haptic feedback
defaults write NSGlobalDomain com.apple.trackpad.forceClick -bool true
defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -bool false
defaults write com.apple.AppleMultitouchTrackpad ActuateDetents -bool true

# Enable Tap to click (tap with one finger).
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# Set keyboard input sources
defaults write com.apple.HIToolbox AppleEnabledInputSources -array \
  '{ "InputSourceKind" = "Keyboard Layout"; "KeyboardLayout ID" = 3; "KeyboardLayout Name" = German; }' \
  '{ "Bundle ID" = "com.apple.CharacterPaletteIM"; "InputSourceKind" = "Non Keyboard Input Method"; }'
