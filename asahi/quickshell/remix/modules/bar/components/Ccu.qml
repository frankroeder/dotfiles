import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../"

// CCu chip: quota remaining + cost overview from asahi-ccu.
Rectangle {
  id: root

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  color: ccuMouse.containsMouse || popup.shouldShow ? Style.barHoverBg : Style.barBg
  radius: Style.radius
  border.width: 1
  border.color: ccuMouse.containsMouse || popup.shouldShow ? Style.barHoverBorder : Style.barBorder
  scale: ccuMouse.containsMouse || popup.shouldShow ? 1.018 : 1.0
  implicitWidth: Math.max(68, row.implicitWidth + 14)
  implicitHeight: 26
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
  property int providerIndex: 0
  property string tooltip: ""
  property double lastFetch: 0

  readonly property var provider: {
    const list = root.overview || []
    if (list.length === 0) return null
    const i = Math.max(0, Math.min(root.providerIndex, list.length - 1))
    return list[i]
  }
  readonly property bool hasValue: usedPct !== null && usedPct !== undefined
  readonly property string valueText: {
    if (hasError && !hasValue) return "?"
    if (hasValue) return Math.round(usedPct) + "%"
    return ""
  }
  readonly property color valueColor: {
    if (hasError && !hasValue) return Style.red
    return usageColor(usedPct)
  }
  readonly property bool alarming: hasValue && usedPct >= 90

  function usageColor(used) {
    if (used === null || used === undefined) return Style.textMuted
    if (used >= 90) return Style.red
    if (used >= 75) return Style.orange
    if (used >= 50) return Style.yellow
    return Style.teal
  }

  function fmtTokens(n) {
    n = Number(n) || 0
    if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
    if (n >= 1e3) return Math.round(n / 1e3) + "k"
    return String(Math.round(n))
  }

  function fmtUsd(u) {
    u = Number(u) || 0
    if (u >= 1000) return "$" + (u / 1000).toFixed(1) + "k"
    if (u >= 100) return "$" + Math.round(u)
    return "$" + u.toFixed(2)
  }

  function heroMeta(p) {
    if (!p) return ""
    const limits = p.limits || []
    let best = null
    for (let i = 0; i < limits.length; i++) {
      if (limits[i].percent == null) continue
      if (!best || limits[i].percent > best.percent) best = limits[i]
    }
    if (best && best.percent != null)
      return Math.round(best.percent * 100) + "% of " + (best.title || "limit").toLowerCase()
    const week = p.week || {}
    if (week.tokens) return fmtTokens(week.tokens) + " tokens · 7d"
    return "Subscription"
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
    root.tooltip = data.tooltip || ""
    if (root.providerIndex >= root.overview.length)
      root.providerIndex = 0
  }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: "󱚣"
      font { family: Style.fontFamily; pixelSize: 14 }
      color: root.alarming ? Style.red : Style.text
      verticalAlignment: Text.AlignVCenter
    }
    Text {
      visible: root.valueText !== ""
      text: root.valueText
      font { family: Style.fontFamily; pixelSize: Style.fontSize }
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
    interval: popup.shouldShow ? 45000 : 90000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.lastFetch = 0
      root.refresh()
    }
  }

  MouseArea {
    id: ccuMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.MiddleButton && root.overview.length > 1) {
        root.providerIndex = (root.providerIndex + 1) % root.overview.length
        return
      }
      if (mouse.button === Qt.RightButton && root.provider && root.provider.url) {
        Quickshell.execDetached(["xdg-open", root.provider.url])
        return
      }
      popup.shouldShow = !popup.shouldShow
      if (popup.shouldShow) {
        root.lastFetch = 0
        root.refresh()
      }
    }
  }

  TooltipWindow {
    target: root
    text: root.tooltip
    show: ccuMouse.containsMouse && !popup.shouldShow
    maxWidth: 380
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
      implicitWidth: 380
      implicitHeight: col.implicitHeight + 24

      Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        Row {
          width: parent.width
          spacing: 10
          Text {
            text: "󱚣"
            font { family: Style.fontFamily; pixelSize: 22 }
            color: root.alarming ? Style.red : Style.text
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            spacing: 2
            Text {
              text: root.provider ? root.provider.name : "Agents"
              font { family: Style.fontFamily; pixelSize: 14; bold: true }
              color: Style.text
            }
            Text {
              text: root.heroMeta(root.provider)
              font { family: Style.fontFamily; pixelSize: 11 }
              color: Style.textMuted
            }
          }
        }

        Row {
          visible: root.overview.length > 1
          width: parent.width
          spacing: 6
          Repeater {
            model: root.overview
            Rectangle {
              required property var modelData
              required property int index
              width: (col.width - 6 * Math.max(0, root.overview.length - 1)) / Math.max(1, root.overview.length)
              height: 24
              color: index === root.providerIndex ? Qt.alpha(Style.text, 0.18) : Qt.alpha(Style.text, 0.04)
              radius: 0
              Text {
                anchors.centerIn: parent
                text: modelData.name
                font { family: Style.fontFamily; pixelSize: 11 }
                color: Style.text
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.providerIndex = index
              }
            }
          }
        }

        Text {
          visible: !root.provider
          width: parent.width
          text: "No AI coding subscriptions found.\nAgents show up here once you've used them."
          color: Style.textMuted
          font { family: Style.fontFamily; pixelSize: 12 }
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }

        Column {
          visible: root.provider && (root.provider.limits || []).length > 0
          width: parent.width
          spacing: 8
          Text {
            text: "LIMITS"
            font { family: Style.fontFamily; pixelSize: 10; bold: true }
            color: Style.textMuted
          }
          Repeater {
            model: root.provider ? (root.provider.limits || []) : []
            Column {
              required property var modelData
              width: col.width
              spacing: 4
              Row {
                width: parent.width
                Text {
                  width: parent.width - pctLabel.width
                  text: modelData.title || ""
                  font { family: Style.fontFamily; pixelSize: 12 }
                  color: Style.text
                  elide: Text.ElideRight
                }
                Text {
                  id: pctLabel
                  text: modelData.percent == null ? (modelData.label || "—") : (Math.round(modelData.percent * 100) + "%")
                  font { family: Style.fontFamily; pixelSize: 11 }
                  color: (modelData.percent || 0) >= 0.9 ? Style.red : Style.textMuted
                }
              }
              Rectangle {
                width: parent.width
                height: 4
                color: Qt.alpha(Style.text, 0.12)
                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1, Number(modelData.percent) || 0))
                  height: parent.height
                  color: (modelData.percent || 0) >= 0.9 ? Style.red : Style.text
                }
              }
              Text {
                visible: (modelData.reset || "") !== ""
                text: modelData.reset
                font { family: Style.fontFamily; pixelSize: 10 }
                color: Style.textMuted
              }
            }
          }
        }

        Column {
          visible: root.provider && (root.provider.today || root.provider.week || root.provider.total)
          width: parent.width
          spacing: 4
          Text {
            text: "COST"
            font { family: Style.fontFamily; pixelSize: 10; bold: true }
            color: Style.textMuted
          }
          Text {
            visible: !!(root.provider && root.provider.today)
            text: root.provider && root.provider.today
              ? ("Today  " + root.fmtUsd(root.provider.today.usd) + " · " + root.fmtTokens(root.provider.today.tokens))
              : ""
            font { family: Style.fontFamily; pixelSize: 11 }
            color: Style.text
          }
          Text {
            visible: !!(root.provider && root.provider.week)
            text: root.provider && root.provider.week
              ? ("7 days  " + root.fmtUsd(root.provider.week.usd) + " · " + root.fmtTokens(root.provider.week.tokens))
              : ""
            font { family: Style.fontFamily; pixelSize: 11 }
            color: Style.text
          }
          Text {
            visible: !!(root.provider && root.provider.total)
            text: root.provider && root.provider.total
              ? ("All time  " + root.fmtUsd(root.provider.total.usd) + " · " + root.fmtTokens(root.provider.total.tokens))
              : ""
            font { family: Style.fontFamily; pixelSize: 11 }
            color: Style.textMuted
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
