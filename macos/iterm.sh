################################################################################
# iTerm                                                                        #
################################################################################

# Configure iTerm2 to read preferences from dotfiles
defaults write com.googlecode.iterm2 PrefsCustomFolder ~/.dotfiles/iterm

# Tell iTerm2 to use the custom preferences in the directory
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -int 1
