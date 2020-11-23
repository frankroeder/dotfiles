################################################################################
# Dock                                                                         #
################################################################################

# Wipe all (default) app icons from the Dock
defaults delete com.apple.dock persistent-apps
defaults delete com.apple.dock persistent-others
defaults write com.apple.dock persistent-others -array \
  "<dict><key>tile-data</key>
    <dict><key>file-data</key>
      <dict>
        <key>_CFURLString</key><string>/Users/$(whoami)/Downloads</string>
        <key>_CFURLStringType</key><integer>0</integer>
      </dict>
      <key>displayas</key><integer>1</integer>
      <key>arrangement</key><integer>2</integer>
      <key>showas</key><integer>3</integer>
    </dict>
    <key>tile-type</key><string>directory-tile</string>
  </dict>"

# Show indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool false

# Delete the hiding Dock delay
defaults write com.apple.dock autohide-delay -float 0

# Make the animation when hiding/showing the Dock faster
defaults write com.apple.dock autohide-time-modifier -float 0.15

# Dark menu bar and dock
defaults write NSGlobalDomain AppleInterfaceTheme -string "Dark"
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# Set the icon size of Dock items to 60 pixels
defaults write com.apple.dock tilesize -int 60

# Lock dock size
defaults write com.apple.dock size-immutable -bool true

# Change minimize/maximize window effect
defaults write com.apple.dock mineffect -string "scale"

# Minimize windows into their application’s icon
defaults write com.apple.dock minimize-to-application -bool true

# Don’t animate opening applications from the Dock
defaults write com.apple.dock launchanim -bool false

# Don’t show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -int 1

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -int 1

# Disable bounce animation on notification.
defaults write com.apple.dock no-bouncing -bool true

# Disable iTunes track notifications in the Dock
defaults write com.apple.dock itunes-notifications -bool false
