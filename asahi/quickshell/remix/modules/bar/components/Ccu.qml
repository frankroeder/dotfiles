import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../../../"
import "../BarModel.js" as BarModel

// CCu chip: Grok/Cursor overview from asahi-ccu, matching sketchybar ccu.lua.
Rectangle {
  id: root

  property var barHost: null

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property int contentW: 440

  color: "transparent"
  // As wide as the chip on show: a box sized for the widest provider left a gap before the mic.
  implicitWidth: Math.max(56, chipBoxW + 6)
  Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
  property double updatedAt: 0
  property int clockTick: 0

  readonly property var currentChip: {
    const list = root.chips || []
    if (list.length === 0) return null
    const i = Math.max(0, Math.min(root.chipIndex, list.length - 1))
    return list[i]
  }
  readonly property var provider: (root.overview || [])[0] || null
  // The full chip is "Grok 27% · 17h 30m" (~150px — a quarter of the right
  // cluster). When the notch leaves the bar too little room, BarHost sets `compact` and
  // the reset time drops, leaving "Grok 27%". Either way the detail is in the popup.
  property bool compact: false

  // asahi-ccu pads chips into a monospace column (sketchybar); the bar font is proportional,
  // where the padding shows as gaps ("Grok    27%").
  function squeeze(t) {
    return String(t || "").replace(/\s+/g, " ").trim()
  }

  function providerOf(chip) {
    return String((chip && chip.text) || "").trim().split(/\s+/)[0] || ""
  }

  readonly property string chipText: {
    if (!root.compact && root.currentChip && root.currentChip.text)
      return root.squeeze(root.currentChip.text)
    const name = root.providerOf(root.currentChip)
    if (name === "") return root.hasError ? "CCu ?" : "CCu"
    if (!root.hasValue) return name
    return name + " " + Math.round(root.chipUsed) + "%"
  }
  readonly property var chipUsed: root.currentChip ? root.currentChip.used : root.usedPct
  readonly property bool hasValue: chipUsed !== null && chipUsed !== undefined
  readonly property bool chipFresh: !root.currentChip || root.currentChip.fresh !== false
  readonly property color valueColor: {
    if (root.hasError && !root.hasValue) return Style.red
    return usageColor(chipUsed)
  }
  readonly property bool alarming: hasValue && chipUsed >= 90
  readonly property string updatedLabel: { clockTick; return ago(root.updatedAt) }

  FontMetrics {
    id: chipMetrics
    font.family: Style.fontFamily
    font.pixelSize: Style.barFontBody
  }

  // Measured text widths (the old average-character estimate overshot proportional digits).
  // fullBoxW is the widest uncompacted chip: BarHost's worst case for the notch budget.
  readonly property int fullBoxW: {
    const list = root.chips || []
    let w = 0
    for (let i = 0; i < list.length; i++) w = Math.max(w, chipMetrics.advanceWidth(root.squeeze(list[i].text)))
    return Math.ceil(w)
  }
  readonly property int chipBoxW: Math.ceil(chipMetrics.advanceWidth(root.chipText))

  // What this chip would cost uncompacted — BarHost's cue, and independent of
  // `compact` so asking the question cannot change the answer.
  readonly property real fullWidth: Math.max(56, root.fullBoxW + 6)

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

  function nextChip() {
    if ((root.chips || []).length < 2) return
    root.chipIndex = (root.chipIndex + 1) % root.chips.length
  }

  // The chip box follows the text, so the provider name starts at the same place.
  Text {
    x: 3
    anchors.verticalCenter: parent.verticalCenter
    width: root.chipBoxW
    text: root.chipText
    font { family: Style.fontFamily; pixelSize: Style.barFontBody }
    color: root.valueColor
    opacity: root.chipFresh ? 1 : 0.45
    elide: Text.ElideRight
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on opacity { NumberAnimation { duration: 160 } }
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
    HyprlandFocusGrab {
      windows: [popup, popup.anchor.window]
      active: popup.visible
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
              readonly property real cardW: width
              width: col.width
              spacing: 6

              Rectangle {
                visible: index > 0
                width: parent.width
                height: 1
                color: Qt.alpha(Style.text, 0.14)
              }

              Item {
                width: parent.width
                height: Math.max(nameText.implicitHeight, identText.implicitHeight)

                Text {
                  id: nameText
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: cardData.name || ""
                  font { family: Style.fontFamily; pixelSize: 13; bold: true }
                  color: fill
                }
                Text {
                  anchors.left: nameText.right
                  anchors.leftMargin: 10
                  anchors.right: identText.left
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  text: cardData.head || ""
                  font { family: Style.fontFamily; pixelSize: 12 }
                  color: (cardData.tier || cardData.used != null) ? Style.text : Style.textMuted
                  elide: Text.ElideRight
                }
                Text {
                  id: identText
                  visible: (cardData.ident || "") !== ""
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: cardData.ident || ""
                  font { family: Style.fontFamily; pixelSize: 11 }
                  color: Style.textMuted
                }
              }

              Text {
                visible: cardData.fresh === false
                width: parent.width
                text: { root.clockTick; return root.staleLine(cardData) }
                font { family: Style.fontFamily; pixelSize: 11 }
                color: Style.textMuted
              }

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
                    x: modelData.x * cardW
                    width: Math.max(1, modelData.w * cardW)
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
                visible: (cardData.extras || []).length > 0
                width: parent.width
                spacing: 4
                Repeater {
                  model: cardData.extras
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
              Text {
                required property var modelData
                text: "↗  " + (modelData.title || "")
                font { family: Style.fontFamily; pixelSize: 11 }
                color: linkMa.containsMouse ? Style.sky : Style.textMuted
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
