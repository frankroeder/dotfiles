// Symlinked into each ~/.thunderbird/*.default*/user.js.
// Thunderbird reapplies this on every start, so only prefs that should stay fixed belong here.
// Accounts, calendars, LDAP, and the signature path stay in the profile's prefs.js.

user_pref("extensions.activeThemeID", "default-theme@mozilla.org");
user_pref("layout.css.prefers-color-scheme.content-override", 2);
user_pref("browser.theme.content-theme", 0);
user_pref("browser.theme.toolbar-theme", 0);
user_pref("layout.css.always_underline_links", true);

user_pref("mail.display_glyph", false);
user_pref("mail.inline_attachments", false);
user_pref("mail.threadpane.cardsview.rowcount", 2);
user_pref("mailnews.default_view_flags", 0);
user_pref("mailnews.mark_message_read.delay", true);
user_pref("mailnews.mark_message_read.delay.interval", 7);
user_pref("messenger.options.messagesStyle.theme", "simple");

user_pref("mail.identity.id1.compose_html", false);
user_pref("mail.identity.id1.htmlSigFormat", false);
user_pref("mail.identity.id1.attach_signature", true);
user_pref("mail.identity.id1.attach_vcard", false);
user_pref("mail.identity.id1.reply_on_top", 1);
user_pref("mail.identity.id1.sign_mail", false);

user_pref("calendar.timezone.useSystemTimezone", true);
