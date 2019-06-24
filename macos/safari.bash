################################################################################
# Safari & WebKit                                                              #
################################################################################

# Disable the resume function
defaults write com.apple.Safari NSQuitAlwaysKeepsWindows -int 0

# Disable notifications
defaults write com.apple.Safari CanPromptForPushNotifications -int 0

# Disable the standard delay in rendering a Web page.
defaults write com.apple.Safari WebKitInitialTimedLayoutDelay 0.25

# Disable DNS prefetching (can improve speed)
defaults write com.apple.safari WebKitDNSPrefetchingEnabled -int 0

# Privacy: don’t send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -int 0
defaults write com.apple.Safari SuppressSearchSuggestions -int 1

# Show the full URL in the address bar (note: this still hides the scheme)
defaults write com.apple.Safari ShowFullURLInSmartSearchField -int 1

# Set default search engine to duckduckgo
defaults write -g NSPreferredWebServices '{ NSWebServicesProviderWebSearch =  { NSDefaultDisplayName = DuckDuckGo; NSProviderIdentifier = "com.duckduckgo"; }; }'

# Prevent Safari from opening ‘safe’ files automatically after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -int 0

# Set Safari’s home page to `about:blank` for faster loading
defaults write com.apple.Safari HomePage -string "about:blank"

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -int 1
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -int 1
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -int 1

# Block pop-up windows
defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -int 1
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -int 0

# Disable AutoFill
defaults write com.apple.Safari AutoFillFromAddressBook -int 0
defaults write com.apple.Safari AutoFillPasswords -int 0
defaults write com.apple.Safari AutoFillCreditCardData -int 0
defaults write com.apple.Safari AutoFillMiscellaneousForms -int 0

# Enable “Do Not Track”
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -int 1

# Enable continuous spellchecking
defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -int 1

# Disable auto-correct
defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -int 0

# Warn about fraudulent websites
defaults write com.apple.Safari WarnAboutFraudulentWebsites -int 1

# Update extensions automatically
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -int 1

# Show status bar
defaults write com.apple.Safari ShowStatusBar -bool true
defaults write com.apple.Safari ShowStatusBarInFullScreen -bool true
