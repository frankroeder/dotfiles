// Isolated world: lyrics.js (MAIN world, no extension API there) posts its records to the page; hand them on.
window.addEventListener("message", function (e) {
  if (e.source === window && e.data && e.data.asahiLyrics) chrome.runtime.sendMessage(e.data.asahiLyrics)
})
