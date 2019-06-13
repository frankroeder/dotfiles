################################################################################
# Mail                                                                         #
################################################################################

# Disable send and reply animations in Mail.app
defaults write com.apple.mail DisableReplyAnimations -int 1
defaults write com.apple.mail DisableSendAnimations -int 1

# Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>`
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -int 0

# Disable inline attachments (just show the icons)
defaults write com.apple.mail DisableInlineAttachmentViewing -int 1

# prefer plaintext mails
defaults write com.apple.mail PreferPlainText -int 1
