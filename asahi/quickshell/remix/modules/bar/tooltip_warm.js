.pragma library
// Shared by every bar tooltip (one instance for all importers): while one is shown, or one hid < 600 ms ago, the
// pointer is moving along the bar, so the next one shows at once instead of waiting out its delay. (Enter on the next
// chip can arrive before leave on the last: hence the open count, not only the hide time.)
var open = 0
var hidAt = 0
function opened() { open++ }
function hid() { open = Math.max(0, open - 1); hidAt = Date.now() }
function warm() { return open > 0 || Date.now() - hidAt < 600 }
