################################################################################
# Finder                                                                       #
################################################################################

# disable window animations and Get Info animations
defaults write com.apple.finder DisableAllAnimations -int 1

# show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -int 1

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -int 1

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -int 1
defaults write com.apple.desktopservices DSDontWriteUSBStores -int 1

# Show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -int 1
defaults write com.apple.finder ShowHardDrivesOnDesktop -int 0
defaults write com.apple.finder ShowMountedServersOnDesktop -int 1
defaults write com.apple.finder ShowRemovableMediaOnDesktop -int 1

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -int 0

# Empty Trash securely by default
defaults write com.apple.finder EmptyTrashSecurely -int 1

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -int 1

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv` `Nlsv`
defaults write com.apple.finder FXPreferredViewStyle -string 'Nlsv'

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -int 0

# Allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -int 1

# Show the ~/Library folder
chflags nohidden ~/Library
