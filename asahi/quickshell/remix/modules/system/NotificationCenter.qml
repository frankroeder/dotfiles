import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../../"
import "../menu" as Menu
import "NotificationModel.js" as Model

Scope {
  id: root

  property var toastScreen: null
  property var historyScreen: null
  // Toasts, newest first, one deck per sender (omarchy 4.5). A closing card keeps its entry until its
  // leave animation ends (`leaving`); arrivals while a deck is open wait in `held` (nothing moves
  // under the pointer; 30 s cap).
  property var toasts: []
  property var leaving: ({})
  readonly property var shownToasts: toasts.filter(t => !leaving[t.key])
  property var held: []
  property string openDeck: ""
  property var heights: ({})
  readonly property var deckLayout: Model.layout(root.shownToasts, root.heights, root.openDeck)
  readonly property int maxDecks: 4
  // An open deck of more would run off the laptop screen (nothing scrolls).
  readonly property int maxPerDeck: 5
  // Live Notification objects of the toasts (tracked: their actions need them), by toast key. A plain
  // map, never bound to: the server destroys an object once it is closed.
  property var refs: ({})
  property var history: []
  property bool historyVisible: false
  property bool dndEnabled: false
  readonly property int historyCount: history.length
  // Persisted across shell restarts; unread = arrived after the sheet was last opened/closed.
  property real lastSeen: 0
  property bool historyLoaded: false
  readonly property int unreadCount: history.filter(e => (e.ts || 0) > lastSeen).length
  readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/asahi/notifications.json"
  readonly property int maxHistory: 100
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  function focusedScreen() {
    const mon = Hyprland.focusedMonitor
    return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
  }

  function urgencyColor(urgency) {
    if (urgency === 2) return Style.red
    if (urgency === 0) return Style.textMuted
    return Style.blueAlt
  }

  // Summary / app name (plain text by spec): known tags only, so "Jane <jane@example.org>" or Vec<String>
  // stays text; the name ends at a space, / or > ("<a.smith@…>" is an address). The body goes through
  // Model.richBody / plainBody.
  function stripMarkup(value) {
    return String(value || "").replace(/<\/?(b|i|u|a|img|span|br)(?=[\s\/>])[^>]*>/gi, "")
      .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
  }

  // Any app on the bus can set image-path, and IconImage will fetch an http
  // URL — so only local sources are rendered; the rest fall back to the app
  // icon (a theme lookup returns "" for a URL).
  function localImage(value) {
    const s = String(value || "")
    // Image data lives as long as the Notification: a history card outlives it (an empty box) and an
    // untracked one is freed right after onNotification.
    if (s.startsWith("image://qsimage/")) return false
    // An image-path that is no file: URL arrives as image://icon/<value>: a theme name, or a path the
    // icon provider opens as a file (same rules as below); `?path=` makes it read that file.
    if (s.startsWith("image://icon/")) {
      const name = s.slice("image://icon/".length)
      return name.indexOf("?path=") < 0 && (name.indexOf("/") < 0 || localImage(name))
    }
    if (!s.startsWith("file:") && !s.startsWith("/")) return false
    // /proc, /sys and /dev hold FIFOs and endless streams that block the load (omarchy #15932). A FIFO
    // elsewhere still blocks it (no stat from QML): only a local process can make one.
    // Resolved like the loader does (%-escapes, file://host/ = //host/, `.`, `..`) before the check.
    let path = s.replace(/^file:(\/\/)?/, "").replace(/[?#].*$/, "")  // the loader drops query + fragment
    try { path = decodeURIComponent(path) } catch (_) { return false }
    const parts = []
    for (const seg of path.split("/")) {
      if (seg === "..") parts.pop()
      else if (seg !== "" && seg !== ".") parts.push(seg)
    }
    return !["proc", "sys", "dev"].includes(parts[0])
  }

  // Firefox and Ghostty send no app name, only a desktop entry id: show the entry's Name.
  function appLabel(e) {
    const d = e.desktopEntry ? DesktopEntries.byId(e.desktopEntry) : null
    return e.appName || (d && d.name) || e.desktopEntry || "Notification"
  }

  function iconFor(entry) {
    if (!entry) return ""
    if (localImage(entry.image)) return entry.image
    const raw = entry.appIcon || entry.desktopEntry || entry.appName || ""
    // An app icon given as a path is opened as a file too: the same rules.
    if (raw.indexOf("/") >= 0 && !localImage(raw)) return ""
    return raw ? Quickshell.iconPath(raw, true) : ""
  }

  function snapshot(n, key) {
    const e = {
      key: key || String(Date.now()) + "-" + Math.floor(Math.random() * 10000),
      appName: stripMarkup(n.appName || ""),
      appIcon: String(n.appIcon || ""),
      desktopEntry: String(n.desktopEntry || ""),
      image: String(n.image || ""),
      summary: stripMarkup(n.summary || ""),
      // Body markup is on: plain text for dedup / codes, sanitised StyledText (links) for the card.
      body: Model.plainBody(n.body),
      rich: Model.richBody(n.body),
      urgency: Number(n.urgency),
      // App-requested lifetime: the raw D-Bus value in ms (notify-send -t); <= 0 = server default.
      expire: Number(n.expireTimeout) || 0,
      ts: Date.now(),
      count: 1,
      actions: Model.actionList(n.actions)
    }
    e.group = appLabel(e).toLowerCase()
    e.codes = Model.detectCodes(e.summary + "\n" + e.body)
    return e
  }

  // Upstream relative times; clockTick re-evaluates them every 10 s while a card is on screen.
  property int clockTick: 0
  Timer { interval: 10000; repeat: true; running: root.historyVisible || root.toasts.length > 0; onTriggered: root.clockTick++ }
  function relTime(ts, _tick) {
    const d = new Date(ts || 0), sec = (Date.now() - d) / 1000
    if (sec < 60) return "now"
    if (sec < 3600) return Math.floor(sec / 60) + " min ago"
    return Qt.formatTime(d, "HH:mm")  // day headers in the history say which day
  }

  // History grouped per day by app (upstream NotificationManager): groups keep the order of their
  // newest entry; a group with several shows the newest card until expanded.
  property var expandedGroups: ({})
  // Built only while the sheet is open: day labels are fresh on every open (they went stale past
  // midnight), and a hidden sheet no longer rebuilds every card per notification.
  readonly property var historyGroups: {
    const out = [], idx = {}
    if (!root.historyVisible) return out
    for (const e of root.history) {
      const day = root.dayLabel(e.ts), app = root.appLabel(e)
      const k = day + "|" + app
      if (idx[k] === undefined) { idx[k] = out.length; out.push({ key: k, day: day, app: app, items: [] }) }
      out[idx[k]].items.push(e)
    }
    return out
  }
  function toggleGroup(k) {
    const g = Object.assign({}, root.expandedGroups)
    if (g[k]) delete g[k]
    else g[k] = true
    root.expandedGroups = g
  }
  function dismissGroup(group) {
    const keys = group.items.map(e => e.key)
    root.history = root.history.filter(e => keys.indexOf(e.key) < 0)
  }

  // Day, not hour: what you remember about a notification you hunt for is the day.
  function dayLabel(ts) {
    const d = new Date(ts || 0)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const days = Math.round((today - new Date(d).setHours(0, 0, 0, 0)) / 86400000)
    if (days <= 0) return "Today"
    if (days === 1) return "Yesterday"
    if (days < 7) return Qt.formatDate(d, "dddd")
    return Qt.formatDate(d, "d MMM yyyy")
  }

  // Focus the sender's most recently used window by class (never-focused ones are -1: last). Never runs
  // anything the notification carried.
  function focusApp(entry) {
    Quickshell.execDetached(["sh", "-c",
      "a=$(hyprctl clients -j | jq -r --arg d \"$1\" --arg n \"$2\" " +
      "'[.[] | select((.class | ascii_downcase) as $c | $c == ($d | ascii_downcase) or $c == ($n | ascii_downcase))]" +
      " | sort_by(if .focusHistoryID < 0 then 1e9 else .focusHistoryID end) | .[0].address // empty'); " +
      "[ -n \"$a\" ] && hyprctl dispatch \"hl.dsp.focus({ window = \\\"address:$a\\\" })\"",
      "sh", entry.desktopEntry || "", entry.appName || ""])
  }

  function save() {
    if (root.historyLoaded) histFile.setText(JSON.stringify({ lastSeen: root.lastSeen, dnd: root.dndEnabled, history: root.history }))
  }
  onHistoryChanged: save()
  onLastSeenChanged: save()
  // Saved too: any QML save reloads the shell, which silently turned Do Not Disturb off.
  onDndEnabledChanged: save()

  function addHistory(entry) {
    let next = root.history.slice()
    if (entry.appName === "Asahi Battery") next = next.filter(item => item.appName !== "Asahi Battery")
    next.unshift(entry)
    root.history = next.slice(0, root.maxHistory)
  }

  function addToast(entry) {
    // The deck stays on the monitor that was focused when its first card came, until it empties.
    if (root.toasts.length === 0 && root.held.length === 0 || Quickshell.screens.indexOf(root.toastScreen) < 0)
      root.toastScreen = focusedScreen()
    // The battery daemon repeats its critical alert every minute: replace, never stack (as history).
    if (entry.appName === "Asahi Battery")
      for (const t of root.toasts.concat(root.held)) if (t.appName === "Asahi Battery") closeToast(t.key, "expire")
    if (root.openDeck !== "") { root.held = [entry].concat(root.held); heldCap.start(); return }
    showToast(entry)
  }
  function showToast(entry) {
    root.toasts = [entry].concat(root.toasts)
    for (const key of Model.overflowKeys(root.shownToasts, root.maxDecks, root.maxPerDeck)) closeToast(key, "expire")
  }
  function flushHeld() {
    heldCap.stop()
    const list = root.held
    root.held = []
    for (let i = list.length - 1; i >= 0; i--) showToast(list[i])
  }
  // A pointer parked over a deck must not hold new cards back for good.
  Timer { id: heldCap; interval: 30000; onTriggered: root.flushHeld() }
  onOpenDeckChanged: if (openDeck === "") flushHeld()

  function replaceToast(entry) {
    const swap = list => list.map(t => t.key === entry.key ? entry : t)
    root.toasts = swap(root.toasts)
    root.held = swap(root.held)
  }

  // A closing card rises out the way it came (200 ms), then its entry goes. how: "dismiss" (you),
  // "expire" (timeout, overflow) or "" (the sender closed it).
  function closeToast(key, how) {
    if (how) release(key, how)
    if (root.held.some(t => t.key === key)) { root.held = root.held.filter(t => t.key !== key); return }
    if (root.leaving[key] || !root.toasts.some(t => t.key === key)) return
    const l = Object.assign({}, root.leaving)
    l[key] = Date.now()
    root.leaving = l
  }
  // Each closing card goes 220 ms after it started (one restarted timer never fired under a flood).
  Timer {
    interval: 100
    repeat: true
    running: Object.keys(root.leaving).length > 0
    onTriggered: {
      const now = Date.now(), keep = {}
      for (const k in root.leaving) if (now - root.leaving[k] < 220) keep[k] = root.leaving[k]
      if (Object.keys(keep).length === Object.keys(root.leaving).length) return
      root.toasts = root.toasts.filter(t => !root.leaving[t.key] || keep[t.key])
      root.leaving = keep
      const h = {}
      for (const t of root.toasts) if (root.heights[t.key]) h[t.key] = root.heights[t.key]
      root.heights = h
    }
  }
  // The open deck's last card went (dismissed, closed by its sender) under a still pointer: nothing else
  // would resume the countdowns or release the held cards. Next tick: openDeck feeds deckLayout.
  function dropStaleDeck() {
    if (root.openDeck !== "" && !root.deckLayout.decks.some(d => d.key === root.openDeck)) root.openDeck = ""
  }
  onDeckLayoutChanged: Qt.callLater(root.dropStaleDeck)

  // One countdown tick for every toast (a Timer per card woke the shell up to 80 times a second).
  property int toastTick: 0
  Timer { interval: 250; repeat: true; running: root.toasts.length > 0; onTriggered: root.toastTick++ }
  function noteHeight(key, h) {
    if (Math.abs((root.heights[key] || 0) - h) < 0.5) return
    const next = Object.assign({}, root.heights)
    next[key] = h
    root.heights = next
  }

  // Tracked: the object (and its actions) lives until it is closed. A replace (replaces_id) updates it in
  // place, one signal per changed property: the card is rebuilt once, next tick.
  property var updating: ({})
  function track(n, key) {
    n.tracked = true
    root.refs[key] = n
    n.closed.connect(() => root.senderClosed(key, n))
    const update = () => {
      if (root.refs[key] !== n || root.updating[key]) return
      root.updating[key] = true
      Qt.callLater(() => {
        delete root.updating[key]
        if (root.refs[key] === n) root.updateToast(key, n)
      })
    }
    for (const sig of [n.summaryChanged, n.bodyChanged, n.actionsChanged, n.urgencyChanged, n.imageChanged, n.expireTimeoutChanged])
      sig.connect(update)
  }
  function senderClosed(key, n) {
    if (root.refs[key] !== n) return
    delete root.refs[key]
    // Closed by its sender: an identical resend right after is no burst duplicate.
    if (root.lastEntry && root.lastEntry.key === key) root.lastEntry = null
    closeToast(key, "")
  }
  // Tell the sender; the `closed` that follows finds no ref and is ignored.
  function release(key, how) {
    const n = root.refs[key]
    delete root.refs[key]
    if (!n) return
    if (how === "expire") n.expire()
    else n.dismiss()
  }
  function updateToast(key, n) {
    const old = root.toasts.concat(root.held).find(t => t.key === key)
    if (!old) return
    const entry = Object.assign(snapshot(n, key), { count: old.count })
    replaceToast(entry)
    root.history = root.history.map(e => e.key === key ? Model.historyCopy(entry) : e)
  }
  // An identical repeat of a card still up: ×N on that card, one history entry, a fresh timer. The card
  // comes to the front, its deck to the top (a back card's ×N was a hidden sliver); in place while a
  // deck is open (nothing moves under the pointer).
  function repeatToast(twin, n, entry) {
    release(twin.key, "expire")  // the older copy is superseded (not dismissed by you)
    track(n, twin.key)
    const next = Object.assign({}, entry, { key: twin.key, count: (twin.count || 1) + 1 })
    const front = list => list.some(t => t.key === twin.key) ? [next].concat(list.filter(t => t.key !== twin.key)) : list
    if (root.openDeck !== "") replaceToast(next)
    else { root.toasts = front(root.toasts); root.held = front(root.held) }
    const h = root.history.find(e => e.key === twin.key)
    if (h) root.history = [Object.assign({}, h, { count: next.count, ts: next.ts })].concat(root.history.filter(e => e.key !== twin.key))
  }

  function runButton(key, b) {
    if (b.kind === "code") { copySecret(b.value); return }
    const n = root.refs[key]
    if (!n) return
    for (let i = 0; i < n.actions.length; i++) {
      if (n.actions[i].identifier !== b.id) continue
      // A non-resident notification closes itself after the action (closed -> the card leaves).
      n.actions[i].invoke()
      return
    }
  }

  // Card click: the sender's `default` action when it sent one (what clicking a notification means), and
  // the sender raised; else its window focused. The card goes either way.
  function activate(entry) {
    const n = root.refs[entry.key]
    let def = null
    for (let i = 0; n && i < n.actions.length; i++) if (n.actions[i].identifier === "default") def = n.actions[i]
    if (def) {
      def.invoke()
      root.raiseEntry = entry
      raiseFallback.restart()
    } else root.focusApp(entry)
    root.closeToast(entry.key, "dismiss")
  }

  // The default action also raises the sender. Quickshell sends no xdg-activation token, so the app's own
  // present() goes nowhere: Ghostty's is refused (focus_on_activate = false: the window only turns
  // urgent), Firefox has no token to ask with. Focus the window that turns urgent within 500 ms (the
  // right Ghostty window, its tab already switched), else the sender's most recent window by class.
  property var raiseEntry: null
  Timer {
    id: raiseFallback
    interval: 500
    onTriggered: {
      if (root.raiseEntry) root.focusApp(root.raiseEntry)
      root.raiseEntry = null
    }
  }
  Connections {
    target: root.raiseEntry ? Hyprland : null  // every Hyprland event passes here: only while a raise waits
    function onRawEvent(event) {
      const e = root.raiseEntry
      if (event.name !== "urgent" || !e || !/^[0-9a-f]+$/.test(event.data)) return
      // Another app's window turning urgent meanwhile is not the sender.
      const w = Hyprland.toplevels.values.find(t => t.address === event.data || t.address === "0x" + event.data)
      const cls = String(w && w.wayland ? w.wayland.appId : "").toLowerCase()
      if (!cls || (cls !== e.desktopEntry.toLowerCase() && cls !== e.appName.toLowerCase())) return
      raiseFallback.stop()
      root.raiseEntry = null
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:0x" + event.data + "\" })"])
    }
  }

  // Codes reach the clipboard as sensitive (asahi-cliphist skips them) on stdin, never argv, and are
  // cleared after 60 s if the clipboard still holds them.
  property string copiedSecret: ""
  function copySecret(code) {
    copyProc.pending = code
    copyProc.stdinEnabled = true
    if (copyProc.running) copyProc.running = false
    copyProc.running = true
    root.copiedSecret = code
    secretClear.restart()
  }
  Process {
    id: copyProc
    command: ["wl-copy", "--sensitive"]
    stdinEnabled: true
    property string pending: ""
    onStarted: { write(pending); stdinEnabled = false }
  }
  Timer { id: secretClear; interval: 60000; onTriggered: pasteCheck.running = true }
  Process {
    id: pasteCheck
    command: ["timeout", "2", "wl-paste", "-n"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.copiedSecret !== "" && text === root.copiedSecret) Quickshell.execDetached(["wl-copy", "--clear"])
        root.copiedSecret = ""
      }
    }
  }

  property var lastEntry: null
  function handleNotification(n) {
    const entry = snapshot(n)
    // Burst guard (upstream): the same notification again within 100 ms is a duplicate; different
    // ones arriving together are all kept.
    const prev = root.lastEntry
    root.lastEntry = entry
    if (prev && entry.ts - prev.ts < 100 && entry.appName === prev.appName
      && entry.summary === prev.summary && entry.body === prev.body) return
    const quiet = dndEnabled && entry.urgency !== 2
    if (!quiet) Quickshell.execDetached([root.binDir + "/asahi-notification-sound"])
    const twin = entry.appName === "Asahi Battery" ? null
      : root.toasts.concat(root.held).find(t => !root.leaving[t.key] && Model.sameContent(t, entry))
    if (twin) { repeatToast(twin, n, entry); return }
    addHistory(Model.historyCopy(entry))
    // Shown under Do Not Disturb too, silently: a screenshot's confirmation (also OCR / QR) answers
    // your own key press, Asahi Battery's "Charging" card replaces a critical one, a login code is awaited.
    const login = Model.isLoginCode(entry.summary + "\n" + entry.body, entry.codes)
    if (!quiet || entry.appName === "screenshot" || entry.appName === "Asahi Battery" || login) {
      track(n, entry.key)
      addToast(entry)
    }
  }

  // Hyprland draws layer popups (every bar popup) above the overlay layer, so an open one covered
  // the toasts. Each bar reports which half its open popup hangs in ("left" / "right" / ""); a right
  // one sends the toasts to the top-left corner.
  property var popupSides: ({})
  function setPopupSide(screenName, side) {
    const s = Object.assign({}, root.popupSides)
    s[screenName] = side
    root.popupSides = s
  }
  readonly property string popupSide: root.toastScreen ? (root.popupSides[root.toastScreen.name] || "") : ""

  // The bell click that ends the focus grab would reopen the sheet right away: ignore it.
  property real grabClosedAt: 0
  function toggleHistory() {
    if (!historyVisible && Date.now() - grabClosedAt < 300) return
    historyScreen = focusedScreen()
    historyVisible = !historyVisible
  }
  // Every open/close (bell, Esc, click outside, card click) marks the history seen.
  onHistoryVisibleChanged: {
    lastSeen = Date.now()
    // The toast window unmaps under a pointer that may rest on an open deck: no hover-leave comes, and
    // the held cards would wait for it.
    if (historyVisible) openDeck = ""
    else armGrab.armed = false
  }

  function clearHistory() {
    root.history = []
    for (const t of root.toasts.concat(root.held)) closeToast(t.key, "dismiss")
  }

  function toggleDnd() {
    dndEnabled = !dndEnabled
  }

  // Super+comma dismisses the newest popup; Super+Shift+comma dismisses everything, popups and the
  // saved list (popups only did nothing once they had timed out).
  function dismissOne() {
    if (root.shownToasts.length > 0) closeToast(root.shownToasts[0].key, "dismiss")
  }

  function dismissAll() {
    root.clearHistory()
  }

  NotificationServer {
    bodySupported: true
    // Markup and links reach the card only through Model.richBody (b/i/u/s, br, safe http(s) anchors).
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    actionsSupported: true
    imageSupported: true
    // A reload would re-emit the tracked ones: a second history entry each.
    keepOnReload: false
    onNotification: (n) => root.handleNotification(n)
  }

  // Private file (0600, non-atomic writes keep the mode); load only after it exists.
  Process {
    running: true
    command: ["sh", "-c", "umask 077; mkdir -p \"$(dirname \"$1\")\" && touch \"$1\" && chmod 600 \"$1\"", "sh", root.historyPath]
    onExited: histFile.path = root.historyPath
  }

  FileView {
    id: histFile
    atomicWrites: false
    onLoaded: {
      const raw = histFile.text().trim()
      const saved = raw ? JSON.parse(raw) : {}
      root.lastSeen = saved.lastSeen || 0
      root.dndEnabled = !!saved.dnd
      root.history = root.history.concat(saved.history || []).slice(0, root.maxHistory)
      // Only after the merge: loading must not write the file back (a second instance or a
      // config reload re-saving on load could race a write and persist a short history).
      root.historyLoaded = true
    }
  }

  IpcHandler {
    target: "notifications"
    function toggleHistory(): void { root.toggleHistory() }
    function clear(): void { root.clearHistory() }
    function toggleDnd(): void { root.toggleDnd() }
    function dismissOne(): void { root.dismissOne() }
    function dismissAll(): void { root.dismissAll() }
  }

  PanelWindow {
    // Top-right under the bar (omarchy 4.5): the surface's top edge is the bar's floor, so cards drop
    // out from under the bar and rise back into it. Hidden while the sheet (also top-right) is open, the
    // countdowns paused: the sheet masks codes, so a code toast is back to copy once it closes.
    visible: root.toasts.length > 0 && !root.historyVisible
    color: "transparent"
    screen: root.toastScreen
    // Normal + zone 0: sit below the bar's exclusive zone (notch floor).
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    // Full height, fixed width: the surface never resizes (a shrinking one clipped leave animations);
    // the mask lets clicks outside the cards through.
    anchors { top: true; bottom: true; right: root.popupSide !== "right"; left: root.popupSide === "right" }
    margins { left: Style.barEdgeMargin; right: Style.barEdgeMargin }
    implicitWidth: 380
    mask: Region { item: deckArea }

    Item {
      id: deckArea
      y: 6
      width: parent.width
      height: root.deckLayout.height

      // The deck under the pointer opens (spreads out); 120 ms grace for crossing the gap to the next.
      // While one is open every countdown pauses and new cards wait (root.held).
      // Imperative, not a binding: opening a deck changes the layout the pointer is tested against.
      HoverHandler {
        onPointChanged: {
          const y = point.position.y
          let k = hovered ? Model.deckAt(root.deckLayout, y) : ""
          // Opening a lower deck collapses the open one above and moves it up, past the pointer:
          // collapse all first, the next move opens whatever is under it then.
          if (k !== "" && k !== root.openDeck && Model.deckAt(Model.layout(root.shownToasts, root.heights, k), y) !== k) k = ""
          if (k !== "") { collapseGrace.stop(); root.openDeck = k }
          else collapseGrace.restart()
        }
        onHoveredChanged: if (!hovered) collapseGrace.restart()
      }
      Timer { id: collapseGrace; interval: 120; onTriggered: root.openDeck = "" }

      // Diffed by key: a card keeps its delegate (timer, animation) when its entry is replaced (×N,
      // sender update). Placed absolutely from Model.layout; Behaviors animate from wherever it is.
      Repeater {
        model: ScriptModel { objectProp: "key"; values: root.toasts }
        delegate: NotificationCard {
          id: toast
          required property var modelData
          readonly property var place: root.deckLayout.places[modelData.key] || null
          readonly property bool gone: !!root.leaving[modelData.key]
          // Initial values, not assignments: a delegate's Behaviors already animate in onCompleted.
          property real restY: place ? place.y : 0
          property real restH: place ? place.height : 0
          property bool restShown: place ? place.front || place.open : true
          property bool settled: false
          onPlaceChanged: if (place) { restY = place.y; restH = place.height; restShown = place.front || place.open }
          Component.onCompleted: {
            root.noteHeight(modelData.key, implicitHeight)
            Qt.callLater(() => toast.settled = true)  // next tick: y and fade animate in from −24 / 0
          }
          onImplicitHeightChanged: root.noteHeight(modelData.key, implicitHeight)
          width: deckArea.width
          height: place ? place.height : (restH || implicitHeight)
          y: toast.settled && !toast.gone ? toast.restY : toast.restY - 24
          z: place ? 1000 - place.depth : 0
          deckScale: place ? place.scale : 1
          fade: toast.settled && !toast.gone && place ? place.opacity : 0
          Behavior on y { NumberAnimation { duration: toast.gone ? 200 : 250; easing.type: Easing.OutCubic } }
          // Snaps while the first real height replaces the 76 px guess.
          Behavior on height { enabled: toast.settled; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          Behavior on fade { NumberAnimation { duration: toast.gone ? 180 : 220; easing.type: Easing.OutCubic } }
          entry: modelData
          compact: false
          live: true
          contentShown: place ? place.front || place.open : restShown
          timeout: !toast.gone
          paused: root.openDeck !== "" || root.historyVisible
          enabled: !toast.gone
          onDismiss: root.closeToast(modelData.key, "dismiss")
          onExpired: root.closeToast(modelData.key, "expire")
          onActivated: root.activate(modelData)
          onButton: (b) => root.runButton(modelData.key, b)
        }
      }
    }
  }

  PanelWindow {
    id: historySheet
    visible: root.historyVisible
    color: "transparent"
    screen: root.historyScreen
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Esc / click outside closes (serpantinum popups); the bar's bell toggles as before.
    // Armed 200 ms after opening: a bar popup / calendar unmapping at the same moment (they close
    // when the sheet opens) would otherwise clear this grab too and shut the sheet at once.
    Timer { id: armGrab; property bool armed: false; interval: 200; running: root.historyVisible && !armed; onTriggered: armed = true }
    HyprlandFocusGrab {
      windows: [historySheet]
      active: root.historyVisible && armGrab.armed
      onCleared: { root.grabClosedAt = Date.now(); root.historyVisible = false }
    }
    Shortcut {
      enabled: root.historyVisible
      sequences: ["Escape"]
      onActivated: root.historyVisible = false
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-center"
    // Under the bell, the bar's last chip (right edge = barEdgeMargin).
    anchors { top: true; right: true }
    margins { top: 8; right: Style.barEdgeMargin }
    implicitWidth: 420
    // Grow with the list up to a cap instead of a fixed tall sheet.
    implicitHeight: Math.max(180, Math.min(560, historyColumn.implicitHeight + historyHeader.implicitHeight + 14 * 2 + 21))

    Rectangle {
      anchors.fill: parent
      radius: Style.menuRadiusLg
      color: Style.menuBg
      border.color: Style.popupBorder
      border.width: Style.popupBorderWidth

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
          id: historyHeader
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: "Notifications"
            font.family: Style.menuSans
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Style.menuInk
          }
          Rectangle {
            visible: root.historyCount > 0
            implicitWidth: countText.implicitWidth + 12
            implicitHeight: 18
            radius: 9
            color: Style.m3primaryContainer
            Text {
              id: countText
              anchors.centerIn: parent
              text: root.historyCount
              font.family: Style.menuSans
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: Style.menuInk
            }
          }
          Item { Layout.fillWidth: true }
          HeaderButton {
            glyph: root.dndEnabled ? "󰂛" : "󰂚"
            tone: root.dndEnabled ? Style.yellow : Style.menuInkDeep
            onClicked: root.toggleDnd()
          }
          // Clearing everything takes two clicks (the first arms it red for 3 s): one stray click on
          // the trash used to wipe the whole saved history.
          Text {
            visible: clearArm.running
            text: "Clear all?"
            font.family: Style.menuSans
            font.pixelSize: 11
            color: Style.red
          }
          HeaderButton {
            glyph: "󰆴"
            tone: clearArm.running ? Style.red : Style.menuInkDeep
            onClicked: {
              if (!clearArm.running) { clearArm.restart(); return }
              clearArm.stop()
              root.clearHistory()
            }
            Timer { id: clearArm; interval: 3000 }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Style.menuSep }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentHeight: historyColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: historyColumn
            width: parent.width
            spacing: 8

            Column {
              visible: root.history.length === 0
              Layout.alignment: Qt.AlignHCenter
              Layout.topMargin: 28
              spacing: 6
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dndEnabled ? "󰂛" : "󰂚"
                font.family: Style.fontFamily
                font.pixelSize: 26
                color: Style.menuInkMuted
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dndEnabled ? "Do not disturb is on" : "No notifications"
                font.family: Style.menuSans
                font.pixelSize: 12
                color: Style.menuInkDeep
              }
            }

            Repeater {
              model: root.historyGroups
              delegate: ColumnLayout {
                id: group
                required property var modelData
                required property int index
                readonly property bool many: modelData.items.length > 1
                readonly property bool open: !many || !!root.expandedGroups[modelData.key]
                Layout.fillWidth: true
                spacing: 6

                Text {
                  visible: group.index === 0 || root.historyGroups[group.index - 1].day !== group.modelData.day
                  Layout.topMargin: group.index === 0 ? 0 : 6
                  text: group.modelData.day
                  font.family: Style.menuSans
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  color: Style.menuInkMuted
                }

                // Group header (2+ from one app): name, count, expand / collapse, clear the group.
                RowLayout {
                  visible: group.many
                  Layout.fillWidth: true
                  Layout.leftMargin: 4
                  spacing: 6
                  Text {
                    text: group.modelData.app
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    Layout.maximumWidth: 220
                    font.family: Style.menuSans
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Style.menuInkDeep
                  }
                  Rectangle {
                    implicitWidth: groupCount.implicitWidth + 10
                    implicitHeight: 16
                    radius: 8
                    color: Style.m3primaryContainer
                    Text {
                      id: groupCount
                      anchors.centerIn: parent
                      text: group.modelData.items.length
                      font.family: Style.menuSans
                      font.pixelSize: 10
                      font.weight: Font.DemiBold
                      color: Style.menuInk
                    }
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    text: group.open ? "Show less" : "Show all"
                    font.family: Style.menuSans
                    font.pixelSize: 11
                    color: toggleMa.containsMouse ? Style.menuSeal : Style.menuInkMuted
                    MouseArea { id: toggleMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleGroup(group.modelData.key) }
                  }
                  Text {
                    text: "󰅖"
                    font.family: Style.fontFamily
                    font.pixelSize: 12
                    color: clearMa.containsMouse ? Style.red : Style.menuInkMuted
                    MouseArea { id: clearMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissGroup(group.modelData) }
                  }
                }

                Repeater {
                  model: group.open ? group.modelData.items : group.modelData.items.slice(0, 1)
                  NotificationCard {
                    required property var modelData
                    Layout.fillWidth: true
                    entry: modelData
                    compact: true
                    timeout: false
                    onDismiss: root.history = root.history.filter(item => item.key !== modelData.key)
                    onActivated: { root.focusApp(modelData); root.historyVisible = false }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  component HeaderButton: MouseArea {
    id: hb
    property string glyph: ""
    property color tone: Style.menuInkDeep
    implicitWidth: 28
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: hb.containsMouse ? Style.m3stateHover : "transparent"
    }
    Text {
      anchors.centerIn: parent
      text: hb.glyph
      font.family: Style.fontFamily
      font.pixelSize: 15
      color: hb.tone
    }
  }

  // Quiet card: hairline border, urgency as a slim left strip (critical also
  // tints the border), app name demoted to the meta line next to the time.
  component NotificationCard: Rectangle {
    id: card

    property var entry: null
    property bool compact: false
    property bool timeout: false
    property bool paused: false
    // A toast with its sender still listening: code / action buttons.
    property bool live: false
    // Back cards of a collapsed deck show only their frame.
    property bool contentShown: true
    property real deckScale: 1
    readonly property color accent: root.urgencyColor(entry ? entry.urgency : 1)
    readonly property bool critical: !!entry && entry.urgency === 2
    readonly property var buttons: {
      if (!card.live || !card.entry) return []
      const codes = card.entry.codes || []
      return codes.map(c => ({ kind: "code", value: c, label: codes.length > 1 ? c : "Copy code" }))
        .concat((card.entry.actions || []).map(a => ({ kind: "action", id: a.id, label: a.text })))
    }
    signal dismiss()
    signal expired()
    signal activated()
    signal button(var b)

    color: card.compact ? Style.m3container : Style.menuBg
    radius: Style.menuRadiusMd
    // Toasts float over windows: the popup outline; history cards sit inside the sheet: hairline.
    border.color: card.critical ? Qt.alpha(Style.red, 0.55) : card.compact ? Style.menuSep : Style.popupBorder
    border.width: card.compact ? 1 : Style.popupBorderWidth
    implicitHeight: cardBody.implicitHeight + 22
    clip: true

    // Upstream timeout rules: critical stays until dismissed; the app's expire time wins over 6 s.
    // Counted down in steps, so a pause (pointer on the card or an open deck, a drag) keeps what is
    // left; a new arrival (×N, sender update) starts over.
    readonly property int lifeMs: {
      if (!card.entry || card.critical) return 0
      const e = Number(card.entry.expire) || 0
      return e > 0 ? e : 6000
    }
    property int remaining: 0
    readonly property real arrival: card.entry ? card.entry.ts : 0
    onArrivalChanged: card.remaining = card.lifeMs
    Component.onCompleted: card.remaining = card.lifeMs
    Connections {
      target: card.timeout && card.lifeMs > 0 && !card.paused && !cardMa.containsMouse && !cardMa.dragging ? root : null
      function onToastTickChanged() {
        card.remaining -= 250
        if (card.remaining <= 0) card.expired()
      }
    }

    // Copy feedback (a tick for 1.4 s); a card whose only point is one code closes after it.
    property string copied: ""
    Timer { id: copiedTick; interval: 1400; onTriggered: card.copied = "" }
    Timer { id: codeTaken; interval: 900; onTriggered: card.dismiss() }

    // Swipe sideways to dismiss (upstream: lock after 6 px, dismiss past 18 % of the width).
    property real dragX: 0
    property real fade: 1  // enter / leave animate this, not opacity (keeps the drag binding)
    transform: Translate { x: card.dragX }
    opacity: card.fade * Math.max(0, 1 - Math.abs(card.dragX) / (card.width * 0.75))
    // Deck slivers shrink from the top edge.
    transformOrigin: Item.Top
    scale: card.deckScale * (cardMa.pressed && !cardMa.dragging ? 0.98 : 1)
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }
    NumberAnimation { id: dragBack; target: card; property: "dragX"; to: 0; duration: 200; easing.type: Easing.OutCubic }
    SequentialAnimation {
      id: dragOut
      property real to: 0
      NumberAnimation { target: card; property: "dragX"; to: dragOut.to; duration: 200; easing.type: Easing.OutQuad }
      ScriptAction { script: card.dismiss() }
    }

    // Critical: a static red tint (a pulse repainted every frame for as long as a battery or timer
    // alert stayed up; same rule as the bar's attention dot).
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      visible: card.critical
      color: Qt.alpha(Style.red, 0.07)
    }

    // Under the row, so the close button (declared later) still wins its clicks.
    MouseArea {
      id: cardMa
      property real startX: 0
      property bool dragging: false
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
      onPressed: (mouse) => { startX = mouse.x; dragging = false; preventStealing = false }
      onPositionChanged: (mouse) => {
        if (!pressed || mouse.buttons !== Qt.LeftButton) return
        if (!dragging && Math.abs(mouse.x - startX) > 6) { dragging = true; preventStealing = true }
        if (dragging) card.dragX = mouse.x - startX
      }
      onReleased: {
        if (!dragging) return
        if (Math.abs(card.dragX) > card.width * 0.18) { dragOut.to = (card.dragX > 0 ? 1.2 : -1.2) * card.width; dragOut.start() }
        else dragBack.start()
      }
      onClicked: (mouse) => {
        if (dragging) { dragging = false; return }
        mouse.button === Qt.RightButton ? card.dismiss() : card.activated()
      }
    }

    Rectangle {
      anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
        topMargin: 10
        bottomMargin: 10
        leftMargin: 5
      }
      width: 3
      radius: 2
      color: card.accent
      opacity: card.entry && card.entry.urgency === 0 ? 0.5 : 1
    }

    RowLayout {
      id: cardBody
      // Top-anchored: a back card cut to the front card's height clips its content, never squeezes it.
      anchors { top: parent.top; left: parent.left; right: parent.right; margins: 11; leftMargin: 16 }
      spacing: 12
      opacity: card.contentShown ? 1 : 0
      enabled: card.contentShown
      Behavior on opacity { NumberAnimation { duration: card.contentShown ? 150 : 75 } }

      Rectangle {
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        Layout.alignment: Qt.AlignTop
        radius: Style.menuRadiusMd - 2
        color: Style.menuControlBg

        IconImage {
          anchors.centerIn: parent
          width: 24
          height: 24
          asynchronous: true  // a sender's path must not stall the shell while it loads
          source: root.iconFor(card.entry)
          visible: source !== ""
        }

        Text {
          anchors.centerIn: parent
          visible: root.iconFor(card.entry) === ""
          text: "󰂚"
          font.family: Style.fontFamily
          font.pixelSize: 16
          color: card.accent
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Text {
            text: card.entry ? root.appLabel(card.entry) : ""
            textFormat: Text.PlainText
            font.family: Style.menuSans
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Style.menuInkDeep
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            visible: !!card.entry && card.entry.count > 1
            text: card.entry ? "×" + card.entry.count : ""
            font.family: Style.menuSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Style.menuSeal
          }
          Text {
            text: card.entry ? root.relTime(card.entry.ts, root.clockTick) : ""
            font.family: Style.menuSans
            font.pixelSize: 11
            color: Style.menuInkMuted
          }
        }

        Text {
          text: card.entry ? card.entry.summary : ""
          visible: text.length > 0
          textFormat: Text.PlainText
          font.family: Style.menuSans
          font.pixelSize: 13
          font.weight: Font.DemiBold
          color: Style.menuInk
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        // The one StyledText in the shell: Model.richBody lets only b/i/u/s, br and safe http(s)
        // anchors through (no img). Without a rich copy (history with codes, entries saved before it)
        // the body is plain already: shown as text, never parsed again (Model.textRich).
        Text {
          text: card.entry ? card.entry.rich ?? Model.textRich(card.entry.body) : ""
          visible: text.length > 0
          textFormat: Text.StyledText
          linkColor: Style.menuSeal
          onLinkActivated: (url) => {
            const u = Model.safeHttpUrl(url)
            if (u) Quickshell.execDetached([root.binDir + "/asahi-launch", "xdg-open", u])
          }
          font.family: Style.menuSans
          font.pixelSize: 12
          color: Style.menuInkDeep
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: card.compact ? 3 : 2
          Layout.fillWidth: true
        }

        // Codes first (copied as sensitive), then the sender's actions (its default runs on a card click).
        Flow {
          visible: card.buttons.length > 0
          Layout.fillWidth: true
          Layout.topMargin: 6
          spacing: 6
          Repeater {
            model: card.buttons
            Menu.MenuPill {
              required property var modelData
              icon: modelData.kind !== "code" ? "" : card.copied === modelData.value ? "󰄬" : "󰆏"
              label: modelData.kind === "code" && card.copied === modelData.value ? "Copied" : modelData.label
              fontScale: 1.1
              implicitHeight: 28
              onClicked: {
                card.button(modelData)
                if (modelData.kind !== "code") return
                card.copied = modelData.value
                copiedTick.restart()
                if (card.buttons.length === 1) codeTaken.start()
              }
            }
          }
        }
      }

      MouseArea {
        id: closeMa
        Layout.preferredWidth: 22
        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignTop
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.dismiss()

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: closeMa.containsMouse ? Style.m3stateHover : "transparent"
        }
        Text {
          anchors.centerIn: parent
          text: "󰅖"
          font.family: Style.fontFamily
          font.pixelSize: 13
          color: closeMa.containsMouse ? Style.red : Style.menuInkMuted
        }
      }
    }
  }
}
