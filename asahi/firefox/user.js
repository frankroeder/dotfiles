// Symlinked into each flatpak Firefox profile; `flatpak override --filesystem=$DOTFILES/asahi/firefox:ro` lets the sandbox follow it.
// Native hosts run on the host via xdg-native-messaging-proxy (Firefox 157+, default 0 = never).
user_pref("widget.use-xdg-desktop-portal.native-messaging-proxy", 1);
// Enable the CaelestiaFox XPI dropped into <profile>/extensions without a prompt
// (default 15 auto-disables every scope; 14 exempts the profile scope, 1).
user_pref("extensions.autoDisableScopes", 14);

// Session: restore previous windows/tabs on start (guide default 1 = homepage).
user_pref("browser.startup.page", 3);
user_pref("browser.sessionstore.resume_from_crash", true);

// Hardening subset of https://brainfucksec.github.io/firefox-hardening-guide-2026
// Skipped on purpose (breakage / conflicts): resistFingerprinting (forces light scheme, breaks
// the live theme), webgl.disabled, clear cookies on shutdown (logs out every start),
// sessionstore.privacy_level 2, disk cache off, safebrowsing off, OCSP.require, https-only.
// Startup / new tab
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
// Recommendations
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("browser.discovery.enabled", false);
// Telemetry / studies / crash reports
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);
// Network prefetch / speculative connections
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.dns.disablePrefetchFromHTTPS", true);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("browser.places.speculativeConnect.enabled", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("network.IDN_show_punycode", true);
// URL bar suggestions / sponsored
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.trending.featureGate", false);
// Forms / passwords (Proton Pass handles credentials)
user_pref("browser.formfill.enable", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
user_pref("signon.formlessCapture.enabled", false);
user_pref("network.auth.subresource-http-auth-allow", 1);
// TLS / certs
user_pref("security.tls.enable_0rtt_data", false);
user_pref("security.cert_pinning.enforcement_level", 2);
user_pref("security.remote_settings.crlite_filters.enabled", true);
user_pref("security.pki.crlite_mode", 2);
// Referer, WebRTC IP leak
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.no_host", true);
// Tracking protection, containers, PDF scripting
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.userContext.enabled", true);
user_pref("privacy.userContext.ui.enabled", true);
user_pref("pdfjs.enableScripting", false);
// Downloads / misc
user_pref("browser.download.start_downloads_in_tmp_dir", true);
user_pref("browser.helperApps.deleteTempFileOnExit", true);
user_pref("browser.download.always_ask_before_handling_new_types", true);
user_pref("browser.pagethumbnails.capturing_disabled", true);
// History stays (no sanitize-on-shutdown). Sync engine choices live in the Firefox account.
user_pref("places.history.enabled", true);
