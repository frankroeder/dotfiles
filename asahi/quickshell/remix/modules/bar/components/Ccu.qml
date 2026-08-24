import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../"

// CCu chip: Grok/Cursor overview from asahi-ccu, matching sketchybar ccu.lua.
Rectangle {
  id: root

  property var barHost: null
  readonly property bool solidBar: barHost !== null && barHost !== undefined

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property int contentW: 440

  color: solidBar
    ? ((ccuMouse.containsMouse || popup.shouldShow) ? Style.barStripHover : "transparent")
    : (ccuMouse.containsMouse || popup.shouldShow ? Style.barHoverBg : Style.barBg)
  radius: solidBar ? 0 : Style.radius
  border.width: solidBar ? 0 : 1
  border.color: solidBar ? "transparent" : (ccuMouse.containsMouse || popup.shouldShow ? Style.barHoverBorder : Style.barBorder)
  scale: solidBar ? 1.0 : (ccuMouse.containsMouse || popup.shouldShow ? 1.018 : 1.0)
  implicitWidth: Math.max(68, Math.max(row.implicitWidth, chipChars * 7.2) + (solidBar ? 8 : 14))
  implicitHeight: solidBar ? Style.barHeight : 26
  visible: available
  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on border.color { ColorAnimation { duration: 140 } }
  Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  property bool available: true
  property var usedPct: null
  property bool hasError: false
  property var rows: []
  property var links: []
  property var overview: []
  property var chips: []
  property int chipIndex: 0
  property int providerIndex: 0
  property int chipChars: 0
  property double lastFetch: 0

  readonly property var currentChip: {
    const list = root.chips || []
    if (list.length === 0) return null
    const i = Math.max(0, Math.min(root.chipIndex, list.length - 1))
    return list[i]
  }
  readonly property var provider: {
    const list = root.overview || []
    if (list.length === 0) return null
    const i = Math.max(0, Math.min(root.providerIndex, list.length - 1))
    return list[i]
  }
  readonly property string chipText: {
    if (root.currentChip && root.currentChip.text)
      return root.currentChip.text
    if (root.hasError) return "CCu ?"
    return "CCu"
  }
  readonly property var chipUsed: root.currentChip ? root.currentChip.used : root.usedPct
  readonly property bool hasValue: chipUsed !== null && chipUsed !== undefined
  readonly property color valueColor: {
    if (root.hasError && !root.hasValue) return Style.red
    return usageColor(chipUsed)
  }
  readonly property bool alarming: hasValue && chipUsed >= 90

  function usageColor(used) {
    if (used === null || used === undefined) return Style.textMuted
    if (used >= 90) return Style.red
    if (used >= 75) return Style.orange
    if (used >= 50) return Style.yellow
    return Style.teal
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

  function refresh() {
    if (ccuProc.running) return
    const now = Date.now()
    if (root.lastFetch > 0 && now - root.lastFetch < 15000) return
    root.lastFetch = now
    ccuProc.running = true
  }

  function apply(data) {
    root.available = data.visible !== false
    root.usedPct = (data.percentage === null || data.percentage === undefined) ? null : data.percentage
    root.hasError = !!data.error
    root.rows = data.rows || []
    root.links = data.links || []
    root.overview = data.overview || []
    root.chips = data.chips || []
    root.chipChars = Number(data.chip_chars) || 0
    if (root.chipIndex >= root.chips.length)
      root.chipIndex = 0
    if (root.providerIndex >= root.overview.length)
      root.providerIndex = 0
  }

  function nextChip() {
    if ((root.chips || []).length < 2) return
    root.chipIndex = (root.chipIndex + 1) % root.chips.length
  }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.chipText
      font { family: Style.fontFamily; pixelSize: 14; bold: true }
      color: root.valueColor
      verticalAlignment: Text.AlignVCenter
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
    interval: popup.shouldShow ? 20000 : 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.lastFetch = 0
      root.refresh()
    }
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
      popup.shouldShow = !popup.shouldShow
      if (popup.shouldShow) {
        root.lastFetch = 0
        root.refresh()
      }
    }
  }

  PopupWindow {
    id: popup
    property bool shouldShow: false
    visible: shouldShow
    color: "transparent"
    anchor.item: root
    anchor.edges: Edges.Bottom
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Rectangle {
      id: card
      anchors.fill: parent
      color: Style.surface
      border.color: Style.barBorder
      border.width: 1
      radius: Style.radius
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

          Text {
            text: "AGENT USAGE"
            font { family: Style.fontFamily; pixelSize: 13; bold: true }
            color: Style.text
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
