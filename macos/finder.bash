################################################################################
# Finder                                                                       #
################################################################################

# disable window animations and Get Info animations
defaults write com.apple.finder DisableAllAnimations -bool true

# show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# desktop is not used at all
# Show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool false

# Empty Trash securely by default
defaults write com.apple.finder EmptyTrashSecurely -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv` `Nlsv`
defaults write com.apple.finder FXPreferredViewStyle -string 'Nlsv'

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Show the ~/Library folder
chflags nohidden ~/Library

# Show Path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true

# Hide desktop items
defaults write com.apple.finder CreateDesktop -bool false

# When performing a search, search the current folder by default
# Possible values:
# * SCev: This Mac
# * SCcf: Current Folder
# * SCsp: Previous Scope
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Set Downloads folder as the default location for new Finder windows.
# Possible values:
# * PfCm: Computer
# * PfVo: Volume
# * PfHm: $HOME
# * PfDe: Desktop
# * PfDo: Documents
# * PfAF: All My Files
# * PfLo: Other
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Downloads/"
