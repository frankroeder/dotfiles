################################################################################
# Storage and SSD-specific                                                     #
################################################################################

# Disable the sudden motion sensor as it’s not useful for SSDs
sudo pmset -a sms 0

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
