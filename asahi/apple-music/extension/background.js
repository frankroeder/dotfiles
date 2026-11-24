// Native messaging is for extension pages only: each lyrics record from relay.js goes to the host, which writes it
// for the shell. One-shot (sendNativeMessage): the host runs per track, nothing stays up between.
chrome.runtime.onMessage.addListener(function (rec) {
  chrome.runtime.sendNativeMessage("asahi.apple_music_lyrics", rec).catch(function () {})
})
