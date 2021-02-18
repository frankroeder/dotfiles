################################################################################
# Mail                                                                         #
################################################################################

# Disable send and reply animations in Mail.app
defaults write com.apple.mail DisableReplyAnimations -bool true
defaults write com.apple.mail DisableSendAnimations -bool true

# Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>`
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

# Disable inline attachments (just show the icons)
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

# prefer plaintext mails
defaults write com.apple.mail PreferPlainText -bool true

# Automatically check for new message
defaults write com.apple.mail AutoFetch -bool true
defaults write com.apple.mail PollTime -string "-1"

# Unread messages in bold
defaults write com.apple.mail ShouldShowUnreadMessagesInBold -bool true

# Play sound "jump" when mail arrives
defaults write com.apple.mail PlayMailSounds -bool true
defaults write com.apple.mail NewMessagesSoundName -string "Frog"

defaults write com.apple.mail BottomPreview -bool false
defaults write com.apple.mail ColumnLayoutMessageList -bool false
defaults write com.apple.mail ConversationViewMarkAllAsRead -bool true
defaults write com.apple.mail ConversationViewSortDescending -bool true
defaults write com.apple.mail ConversationViewSpansMailboxes -bool true
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true
defaults write com.apple.mail DisableReplyAnimations -bool true
defaults write com.apple.mail DisableSendAnimations -bool true
defaults write com.apple.mail EnableContactPhotos -bool false
