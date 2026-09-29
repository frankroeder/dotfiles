// Copied (not linked) into each flatpak Firefox profile: the sandbox cannot see ~/.dotfiles.
// Native hosts run on the host via xdg-native-messaging-proxy (Firefox 157+, default 0 = never).
user_pref("widget.use-xdg-desktop-portal.native-messaging-proxy", 1);
// Enable the CaelestiaFox XPI dropped into <profile>/extensions without a prompt
// (default 15 auto-disables every scope; 14 exempts the profile scope, 1).
user_pref("extensions.autoDisableScopes", 14);
