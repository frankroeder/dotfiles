import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../../../"
import "../BarModel.js" as BarModel
import "marks.js" as Marks

// CCu chip: Grok/Cursor/Claude overview from asahi-ccu. Chip = provider mark, used % of the binding
// window and the reset countdown; a red badge on the mark when another window is at 90 %+ (idea: dancik/limitbar).
Rectangle {
  id: root

  // Provider mark (marks.js), filled in `tint`: a Shape, not a tinted image (no layer pass in the bar).
  // A provider without one (Codex) shows its name instead.
  component Mark: Shape {
    id: markShape
    property string mark: ""
    property color tint: Style.text
    readonly property var def: Marks.paths[mark] || null
    visible: def !== null
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: markShape.tint
      strokeColor: "transparent"
      strokeWidth: 0
      fillRule: markShape.def && markShape.def.evenOdd ? ShapePath.OddEvenFill : ShapePath.WindingFill
      scale: Qt.size(markShape.width / 24, markShape.height / 24)
      PathSvg { path: markShape.def ? markShape.def.d : "" }
    }
  }
  function hasMark(m) { return !!Marks.paths[m] }
  readonly property int markSize: 15
  readonly property int chipGap: 5
  readonly property int hotSize: 5

  property var barHost: null

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property int contentW: 440

  color: "transparent"
  // Fixed width, so nothing shifts as chips rotate (every 10 s): the widest chip, measured, plus the same
  // 8 px pad on both sides. The text is centred, so a shorter chip splits its slack evenly.
  readonly property int chipPad: 8
  implicitWidth: Math.max(56, chipBoxW + 2 * chipPad)
  implicitHeight: Style.barHeight

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: Style.barChipInset
    anchors.bottomMargin: Style.barChipInset
    radius: Style.radiusSm
    // Lit on hover and while the usage popup is open.
    color: ccuMouse.containsMouse || popup.shouldShow ? Style.barStripHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }
  visible: available

  property bool available: true
  property var usedPct: null
  property bool hasError: false
  property var links: []
  property var overview: []
  property var chips: []
  property int chipIndex: 0
  // The chip on show: follows chipIndex halfway through chipSwap (old one rolls up and out, new one in).
  property int shownIndex: 0
  property double updatedAt: 0
  property int clockTick: 0

  readonly property var currentChip: {
    const list = root.chips || []
    if (list.length === 0) return null
    const i = Math.max(0, Math.min(root.shownIndex, list.length - 1))
    return list[i]
  }
  readonly property var provider: (root.overview || [])[0] || null
  // The full chip is "<mark> 27% · 17h 30m". When the notch leaves the bar too little room, BarHost sets
  // `compact` and the reset time drops, leaving "<mark> 27%". Either way the detail is in the popup.
  property bool compact: false

  // Shown only before the first asahi-ccu answer.
  readonly property string chipText: root.hasError ? "CCu ?" : "CCu"
  readonly property var chipUsed: root.currentChip ? root.currentChip.used : root.usedPct
  readonly property bool hasValue: chipUsed !== null && chipUsed !== undefined
  readonly property bool chipFresh: !root.currentChip || root.currentChip.fresh !== false
  readonly property color valueColor: {
    if (root.hasError && !root.hasValue) return Style.red
    return usageColor(chipUsed)
  }
  readonly property string updatedLabel: { clockTick; return ago(root.updatedAt) }

  FontMetrics {
    id: chipMetrics
    font.family: Style.fontFamily
    font.pixelSize: Style.barFontBody
  }

  // Width of one chip as laid out by chipRow below (measured: proportional digits).
  function chipW(chip, countdown) {
    let w = (root.hasMark(chip.mark) ? root.markSize : chipMetrics.advanceWidth(chip.label || "")) + root.chipGap
    w += chipMetrics.advanceWidth(chip.pct || "—")
    if (countdown && chip.pct) w += chipMetrics.advanceWidth(" · " + chip.countdown)
    return w
  }
  // The widest chip of the rotation in one form.
  function boxW(countdown) {
    const list = root.chips || []
    let w = 0
    for (let i = 0; i < list.length; i++) w = Math.max(w, root.chipW(list[i], countdown))
    return Math.ceil(w)
  }
  readonly property int fullBoxW: boxW(true)
  readonly property int compactBoxW: boxW(false)
  // Never narrower than the text on show: before the first asahi-ccu answer (no chips) the box would be
  // 0 wide and "CCu" / "CCu ?" elided to nothing.
  readonly property int chipBoxW: Math.max(root.compact ? root.compactBoxW : root.fullBoxW,
    Math.ceil(chipMetrics.advanceWidth(root.chipText)))

  // What this chip would cost uncompacted — BarHost's cue, and independent of
  // `compact` so asking the question cannot change the answer.
  readonly property real fullWidth: Math.max(56, root.fullBoxW + 2 * root.chipPad)

  function usageColor(used) {
    if (used === null || used === undefined) return Style.textMuted
    if (used >= 90) return Style.red
    if (used >= 75) return Style.orange
    if (used >= 50) return Style.yellow
    return Style.teal
  }

  function ago(ts) {
    const t = Number(ts) || 0
    if (t <= 0) return ""
    const sec = Math.max(0, Date.now() / 1000 - t)
    if (sec < 60) return "just now"
    if (sec < 3600) return Math.floor(sec / 60) + "m ago"
    if (sec < 86400) return Math.floor(sec / 3600) + "h ago"
    const d = Math.floor(sec / 86400)
    if (d < 7) return d + "d ago"
    const dt = new Date(t * 1000)
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return months[dt.getMonth()] + " " + dt.getDate()
  }

  function staleLine(card) {
    const when = ago((card && card.fetched_at) || 0)
    return when ? ("stale, last ok " + when) : "stale, last refresh failed"
  }

  function accentColor(name) {
    switch (name) {
      case "teal": return Style.teal
      case "mauve": return Style.mauve
      case "peach": return Style.orange
      case "sky": return Style.sky
      case "blue": return Style.blue
      case "green": return Style.green
      case "pink": return Style.pink
      case "yellow": return Style.yellow
      case "lavender": return Style.lavender
      case "maroon": return Style.maroon
      case "red": return Style.red
      default: return Style.teal
    }
  }

  function meterSegs(card) {
    const cats = (card && card.categories) || []
    const segs = []
    const gap = 2 / root.contentW
    let x = 0
    if (cats.length > 0) {
      for (let i = 0; i < cats.length; i++) {
        let w = Math.max(Number(cats[i].pct) || 0, 2 / root.contentW)
        if (x + w > 1) w = Math.max(0, 1 - x)
        segs.push({
          x: x,
          w: Math.max(0, w - (i < cats.length - 1 ? gap : 0)),
          color: cats[i].color,
          rest: false
        })
        x += w
      }
    } else if (card && card.used != null) {
      x = Math.max(0, Math.min(1, Number(card.used) / 100))
      segs.push({ x: 0, w: x, color: card.accent, rest: false })
    }
    if (x < 0.995) {
      const restX = x > 0 ? x + gap : 0
      segs.push({ x: restX, w: Math.max(0, 1 - restX), color: card ? card.accent : "teal", rest: true })
    }
    return segs
  }

  // A sub-limit tile's meter: red at 90 %+.
  function limitSegs(card, lim) {
    const used = Number(lim.used) || 0
    return root.meterSegs({ used: used, accent: used >= 90 ? "red" : card.accent })
  }

  // Limits under the main window (limits[0] when usage_line is set).
  function subLimits(card) {
    return (card.limits || []).slice(card.usage_line ? 1 : 0)
  }
  // A sub-limit's own reset line is worth showing only when it is not the main window's reset (5 min slack:
  // Claude's Fable week ends a minute after the main week).
  function ownReset(card, lim) {
    const main = card.usage_line ? (card.limits || [])[0] : null
    return !main || Math.abs((Number(lim.reset_unix) || 0) - (Number(main.reset_unix) || 0)) > 300
  }

  function refresh() { if (!ccuProc.running) ccuProc.running = true }
  function closePopup() { if (popup.shouldShow) root.barHost.openPanel = "" }

  function apply(data) {
    root.available = data.visible !== false
    root.usedPct = (data.percentage === null || data.percentage === undefined) ? null : data.percentage
    root.hasError = !!data.error
    root.links = data.links || []
    root.overview = data.overview || []
    root.chips = data.chips || []
    root.updatedAt = Number(data.updated_at) || 0
    if (root.chipIndex >= root.chips.length)
      root.chipIndex = 0
  }

  onChipIndexChanged: if (root.shownIndex !== root.chipIndex || chipSwap.running) chipSwap.restart()
  Component.onCompleted: root.shownIndex = root.chipIndex

  // Rotation: the chip rolls up and fades out, the next one rolls in from below, its mark scaling up.
  SequentialAnimation {
    id: chipSwap
    ParallelAnimation {
      NumberAnimation { target: chipSlide; property: "opacity"; to: 0; duration: 170; easing.type: Easing.InCubic }
      NumberAnimation { target: chipShift; property: "y"; to: -7; duration: 170; easing.type: Easing.InCubic }
    }
    ScriptAction { script: { root.shownIndex = root.chipIndex; chipShift.y = 7 } }
    ParallelAnimation {
      NumberAnimation { target: chipSlide; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
      NumberAnimation { target: chipShift; property: "y"; to: 0; duration: 240; easing.type: Easing.OutCubic }
      NumberAnimation { target: chipMark; property: "scale"; from: 0.55; to: 1; duration: 320; easing.type: Easing.OutBack }
    }
  }

  function nextChip() {
    if ((root.chips || []).length < 2) return
    root.chipIndex = (root.chipIndex + 1) % root.chips.length
  }

  // Centred in the fixed box: equal room to the status icons and to the mic.
  Text {
    visible: !root.currentChip
    anchors.centerIn: parent
    text: root.chipText
    font { family: Style.fontFamily; pixelSize: Style.barFontBody }
    color: root.valueColor
  }

  // Mark (or name) with the red badge, used % in the usage colour, countdown. chipW() mirrors it.
  Item {
    id: chipSlide
    anchors.fill: parent
    Row {
      id: chipRow
      readonly property var chip: root.currentChip || ({})
      readonly property bool hasPct: !!chip.pct
      visible: !!root.currentChip
      anchors.centerIn: parent
      transform: Translate { id: chipShift }
      opacity: root.chipFresh ? 1 : 0.45
      Behavior on opacity { NumberAnimation { duration: 160 } }

      Item {
        width: chipMark.visible ? root.markSize : chipName.implicitWidth
        height: chipName.implicitHeight
        Mark {
          id: chipMark
          mark: chipRow.chip.mark || ""
          width: root.markSize
          height: root.markSize
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          id: chipName
          visible: !chipMark.visible
          text: chipRow.chip.label || ""
          font { family: Style.fontFamily; pixelSize: Style.barFontBody }
          color: Style.text
        }
        // Another window of this provider is at 90 %+ (details in the popup): a badge on the mark's corner,
        // ringed in the bar colour so it reads off the logo.
        Rectangle {
          visible: chipRow.hasPct && !!chipRow.chip.hot
          width: root.hotSize + 2
          height: width
          radius: width / 2
          x: parent.width - width / 2 - 1
          y: (parent.height - root.markSize) / 2 - width / 2 + 1
          color: Style.red
          border.color: Style.barStripBg
          border.width: 1
        }
      }
      Item { width: root.chipGap; height: 1 }
      Text {
        text: chipRow.chip.pct || "—"
        font { family: Style.fontFamily; pixelSize: Style.barFontBody }
        color: root.valueColor
        Behavior on color { ColorAnimation { duration: 200 } }
      }
      Text {
        visible: !root.compact && chipRow.hasPct
        text: " · " + (chipRow.chip.countdown || "")
        font { family: Style.fontFamily; pixelSize: Style.barFontBody }
        color: Style.textMuted
      }
    }
  }

  Process {
    id: ccuProc
    command: ["/usr/bin/python3", binDir + "/asahi-ccu"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.apply(JSON.parse(text.trim()))
        } catch (e) {
          root.hasError = true
        }
      }
    }
  }

  Timer {
    interval: 5 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Only drives the popup's "updated N min ago" labels: tick while it shows.
  Timer {
    interval: 30000
    running: root.updatedAt > 0 && popup.shouldShow
    repeat: true
    triggeredOnStart: true
    onTriggered: root.clockTick++
  }

  Timer {
    interval: 10000
    running: (root.chips || []).length > 1
    repeat: true
    onTriggered: root.nextChip()
  }

  MouseArea {
    id: ccuMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.MiddleButton && (root.chips || []).length > 1) {
        root.nextChip()
        return
      }
      if (mouse.button === Qt.RightButton) {
        let url = ""
        if (root.currentChip) {
          const list = root.overview || []
          for (let i = 0; i < list.length; i++) {
            if (list[i].id === root.currentChip.id) {
              url = list[i].url || ""
              break
            }
          }
        }
        if (!url && root.provider) url = root.provider.url || ""
        if (url) Quickshell.execDetached(["xdg-open", url])
        return
      }
      if (root.barHost) root.barHost.togglePanel("ccu")
      if (popup.shouldShow) root.refresh()
    }
  }

  PopupWindow {
    id: popup
    readonly property bool shouldShow: !!root.barHost && root.barHost.openPanel === "ccu"
    visible: shouldShow
    color: "transparent"
    anchor.item: root
    anchor.edges: Edges.Bottom
    anchor.margins.bottom: -BarModel.popupDrop(root.barHost ? root.barHost.height : Style.barHeight, Style.barHeight)  // negative = below
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Whitelist the bar window too, else the click that opened this counts as outside and closes it.
    // Esc is an app-wide shortcut: the grab may leave keyboard focus on the bar.
    // Armed once mapped (see SysPanel): armed at show time, clicks inside closed the popup.
    Timer { id: grabArm; interval: 150; running: popup.visible }
    HyprlandFocusGrab {
      windows: [popup, popup.anchor.window]
      active: popup.visible && !grabArm.running
      onCleared: root.closePopup()
    }
    Shortcut {
      enabled: popup.visible
      sequences: ["Escape"]
      context: Qt.ApplicationShortcut
      onActivated: root.closePopup()
    }

    Rectangle {
      id: card
      anchors.fill: parent
      color: Style.m3surfaceSolid
      radius: Style.menuRadiusLg
      border.color: Style.popupBorder
      border.width: Style.popupBorderWidth
      implicitWidth: root.contentW + 28
      implicitHeight: Math.min(flick.contentHeight + 28, 720)

      Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 14
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: col
          width: flick.width
          spacing: 8

          Item {
            width: parent.width
            height: titleText.implicitHeight

            Text {
              id: titleText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "AGENT USAGE"
              font { family: Style.menuSans; pixelSize: 13; bold: true }
              color: Style.text
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: root.updatedLabel !== ""
              text: root.updatedLabel
              font { family: Style.fontFamily; pixelSize: 11 }
              color: Style.textMuted
            }
          }

          Text {
            visible: root.overview.length === 0
            width: parent.width
            text: "No AI coding subscriptions found.\nAgents show up here once you've used them."
            color: Style.textMuted
            font { family: Style.fontFamily; pixelSize: 12 }
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: root.overview
            Column {
              required property var modelData
              required property int index
              readonly property var cardData: modelData
              readonly property color fill: root.accentColor(cardData.accent)
              width: col.width
              spacing: 6

              Rectangle {
                visible: index > 0
                width: parent.width
                height: 1
                color: Qt.alpha(Style.text, 0.14)
              }

              // Header: mark, name, plan pill (or the status when there is no plan) … email · renews.
              // Click opens the provider's usage page.
              Item {
                width: parent.width
                height: 20

                Mark {
                  id: cardMark
                  mark: cardData.mark || ""
                  tint: fill
                  width: 16
                  height: 16
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: nameText
                  anchors.left: cardMark.visible ? cardMark.right : parent.left
                  anchors.leftMargin: cardMark.visible ? 8 : 0
                  anchors.verticalCenter: parent.verticalCenter
                  text: cardData.name || ""
                  font { family: Style.fontFamily; pixelSize: 13; bold: true }
                  color: Style.text
                }
                Rectangle {
                  id: planPill
                  visible: !!cardData.tier
                  anchors.left: nameText.right
                  anchors.leftMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  width: planText.implicitWidth + 14
                  height: 18
                  radius: 9
                  color: Qt.alpha(fill, 0.16)
                  Text {
                    id: planText
                    anchors.centerIn: parent
                    text: cardData.tier || ""
                    font { family: Style.fontFamily; pixelSize: 11; weight: Font.DemiBold }
                    color: fill
                  }
                }
                Text {
                  visible: !cardData.tier
                  anchors.left: nameText.right
                  anchors.leftMargin: 10
                  anchors.right: identText.left
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  text: cardData.head || ""
                  font { family: Style.fontFamily; pixelSize: 12 }
                  color: Style.textMuted
                  elide: Text.ElideRight
                }
                Text {
                  id: identText
                  visible: (cardData.ident || "") !== ""
                  anchors.left: planPill.visible ? planPill.right : nameText.right
                  anchors.leftMargin: 10
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  horizontalAlignment: Text.AlignRight
                  text: cardData.ident || ""
                  textFormat: Text.PlainText
                  font { family: Style.fontFamily; pixelSize: 11 }
                  color: Style.textMuted
                  elide: Text.ElideLeft
                }
                MouseArea {
                  anchors.fill: parent
                  enabled: !!cardData.url
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Quickshell.execDetached(["xdg-open", cardData.url])
                }
              }

              Text {
                visible: cardData.fresh === false
                width: parent.width
                text: { root.clockTick; return root.staleLine(cardData) }
                font { family: Style.fontFamily; pixelSize: 11 }
                color: Style.textMuted
              }

              // Main window (weekly / monthly) as before: "N% of weekly limit used" … reset, full-width meter.
              Item {
                visible: (cardData.usage_line || "") !== ""
                width: parent.width
                height: usageText.implicitHeight

                Text {
                  id: usageText
                  anchors.left: parent.left
                  anchors.right: resetText.left
                  anchors.rightMargin: 8
                  text: cardData.usage_line || ""
                  font { family: Style.fontFamily; pixelSize: 12 }
                  color: Style.text
                  elide: Text.ElideRight
                }
                Text {
                  id: resetText
                  anchors.right: parent.right
                  text: cardData.reset_line || ""
                  font { family: Style.fontFamily; pixelSize: 12 }
                  color: Style.textMuted
                }
              }

              Item {
                visible: cardData.used != null || (cardData.categories || []).length > 0
                width: parent.width
                height: 5

                Repeater {
                  model: root.meterSegs(cardData)
                  Rectangle {
                    required property var modelData
                    x: modelData.x * parent.width
                    width: Math.max(1, modelData.w * parent.width)
                    height: 5
                    radius: 2
                    color: modelData.rest
                      ? Qt.alpha(root.accentColor(modelData.color), 0.20)
                      : root.accentColor(modelData.color)
                  }
                }
              }

              Flow {
                visible: (cardData.categories || []).length > 0
                width: parent.width
                spacing: 10
                Repeater {
                  model: cardData.categories
                  Row {
                    required property var modelData
                    spacing: 4
                    Text {
                      text: "●"
                      font { family: Style.fontFamily; pixelSize: 9 }
                      color: root.accentColor(modelData.color)
                    }
                    Text {
                      text: (modelData.label || "") + " " + (modelData.percent || "")
                      font { family: Style.fontFamily; pixelSize: 11 }
                      color: Style.textMuted
                    }
                  }
                }
              }

              // The other windows (session, model pools): mini tiles in two columns, each a small copy of the main
              // block — name … %, thin bar, "Resets Oct 22, 3:20 PM · 2h 4m" — so every edge lines up with the main
              // bar above. The reset line only where it differs from the main window's (not Cursor's pools).
              Grid {
                id: subGrid
                readonly property var items: root.subLimits(cardData)
                readonly property real tileW: (width - columnSpacing) / 2
                visible: items.length > 0
                width: parent.width
                columns: 2
                columnSpacing: 16
                rowSpacing: 8
                topPadding: 2

                Repeater {
                  model: subGrid.items
                  Column {
                    id: tile
                    required property var modelData
                    readonly property bool passed: !!modelData.reset_passed
                    readonly property bool full: !passed && (Number(modelData.used) || 0) >= 90
                    width: subGrid.tileW
                    spacing: 3

                    Item {
                      width: parent.width
                      height: tilePct.implicitHeight
                      Text {
                        anchors.left: parent.left
                        anchors.right: tilePct.left
                        anchors.rightMargin: 6
                        anchors.baseline: tilePct.baseline
                        text: tile.modelData.title || ""
                        font { family: Style.fontFamily; pixelSize: 11 }
                        color: Style.textMuted
                        elide: Text.ElideRight
                      }
                      Text {
                        id: tilePct
                        anchors.right: parent.right
                        text: tile.passed ? "—" : Math.round(Number(tile.modelData.used) || 0) + "%"
                        font { family: Style.fontFamily; pixelSize: 12; bold: tile.full }
                        color: tile.full ? Style.red : Style.text
                      }
                    }
                    Item {
                      id: tileTrack
                      width: parent.width
                      height: 4
                      Repeater {
                        model: tile.passed ? [] : root.limitSegs(cardData, tile.modelData)
                        Rectangle {
                          required property var modelData
                          x: modelData.x * tileTrack.width
                          width: Math.max(1, modelData.w * tileTrack.width)
                          height: tileTrack.height
                          radius: height / 2
                          color: modelData.rest
                            ? Qt.alpha(root.accentColor(modelData.color), 0.20)
                            : root.accentColor(modelData.color)
                        }
                      }
                    }
                    Text {
                      visible: text !== "" && (tile.passed || root.ownReset(cardData, tile.modelData))
                      width: parent.width
                      elide: Text.ElideRight
                      text: tile.passed ? "reset, awaiting update" : (tile.modelData.reset || "")
                      font { family: Style.fontFamily; pixelSize: 10 }
                      color: Style.textMuted
                    }
                  }
                }
              }

              Row {
                visible: !!cardData.has_stats
                width: parent.width
                spacing: 0
                Text {
                  width: parent.width * 0.40
                  text: cardData.total_line || ""
                  font { family: Style.fontFamily; pixelSize: 12 }
                  color: Style.textMuted
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width * 0.30
                  text: cardData.days30_line || ""
                  font { family: Style.fontFamily; pixelSize: 12 }
                  color: Style.textMuted
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width * 0.30
                  text: cardData.week_line || ""
                  font { family: Style.fontFamily; pixelSize: 12 }
                  color: Style.textMuted
                  elide: Text.ElideRight
                }
              }

              Row {
                visible: (cardData.chart || []).length > 0
                width: parent.width
                height: 52
                Repeater {
                  model: cardData.chart
                  Item {
                    required property var modelData
                    width: col.width / Math.max(1, (cardData.chart || []).length)
                    height: 52
                    Text {
                      anchors.top: parent.top
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: modelData.compact || "0"
                      font { family: Style.fontFamily; pixelSize: 9 }
                      color: Style.text
                    }
                    Rectangle {
                      anchors.horizontalCenter: parent.horizontalCenter
                      anchors.bottom: dowLabel.top
                      anchors.bottomMargin: 2
                      width: 10
                      height: 22
                      radius: 1
                      color: Qt.alpha(fill, 0.14)
                      Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * Math.max(0, Math.min(1, Number(modelData.height) || 0))
                        radius: 1
                        color: fill
                      }
                    }
                    Text {
                      id: dowLabel
                      anchors.bottom: parent.bottom
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: modelData.dow || ""
                      font { family: Style.fontFamily; pixelSize: 9 }
                      color: Style.textMuted
                    }
                  }
                }
              }

              Column {
                visible: (cardData.notes || []).length > 0
                width: parent.width
                spacing: 4
                Repeater {
                  model: cardData.notes || []
                  Row {
                    required property var modelData
                    width: col.width
                    Text {
                      width: parent.width * 0.48
                      text: modelData.label || ""
                      font { family: Style.fontFamily; pixelSize: 12 }
                      color: Style.textMuted
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width * 0.52
                      text: modelData.text || ""
                      font { family: Style.fontFamily; pixelSize: 12 }
                      color: Style.text
                      horizontalAlignment: Text.AlignRight
                      elide: Text.ElideRight
                    }
                  }
                }
              }
            }
          }

          Row {
            visible: root.links.length > 0
            spacing: 14
            Repeater {
              model: root.links
              Item {
                required property var modelData
                implicitWidth: linkRow.implicitWidth
                implicitHeight: linkRow.implicitHeight
                Row {
                  id: linkRow
                  spacing: 5
                  Mark {
                    mark: modelData.mark || ""
                    tint: linkText.color
                    width: 11
                    height: 11
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    id: linkText
                    text: (modelData.title || "") + " ↗"
                    font { family: Style.fontFamily; pixelSize: 11 }
                    color: linkMa.containsMouse ? Style.sky : Style.textMuted
                  }
                }
                MouseArea {
                  id: linkMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (modelData.url) Quickshell.execDetached(["xdg-open", modelData.url])
                }
              }
            }
          }
        }
      }
    }
  }
}
