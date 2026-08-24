import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../"
import "../shortcuts_logic.js" as ShortcutsLogic

// Keyboard-shortcuts overview: glyph on the left bar; click opens a
// two-column list of Hyprland bindings (parsed live from bindings.lua).
Rectangle {
  id: root

  property var barHost: null
  readonly property bool solidBar: barHost !== null && barHost !== undefined
  readonly property int descW: 244
  readonly property int keyW: 100
  readonly property int colW: descW + keyW
  readonly property int colGap: 26
  readonly property int framePad: 14

  property var leftCol: []
  property var rightCol: []
  property string sourceLabel: "hypr"

  color: solidBar
    ? ((chipMouse.containsMouse || popup.shouldShow) ? Style.barStripHover : "transparent")
    : (chipMouse.containsMouse || popup.shouldShow ? Style.barHoverBg : Style.barBg)
  radius: solidBar ? 0 : Style.radius
  border.width: solidBar ? 0 : 1
  border.color: solidBar ? "transparent" : (chipMouse.containsMouse || popup.shouldShow ? Style.barHoverBorder : Style.barBorder)
  scale: solidBar ? 1.0 : (chipMouse.containsMouse || popup.shouldShow ? 1.018 : 1.0)
  implicitWidth: solidBar ? glyph.implicitWidth + 10 : 30
  implicitHeight: solidBar ? Style.barHeight : 26
  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on border.color { ColorAnimation { duration: 140 } }
  Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  function rebuild() {
    const text = bindingsFile.text()
    const sections = ShortcutsLogic.parse(text)
    const layout = ShortcutsLogic.layoutColumns(sections)
    root.leftCol = layout.left || []
    root.rightCol = layout.right || []
    root.sourceLabel = layout.source || "hypr"
  }

  FileView {
    id: bindingsFile
    path: Quickshell.env("HOME") + "/.dotfiles/asahi/hypr/conf.d/bindings.lua"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.rebuild()
    onTextChanged: root.rebuild()
  }

  Text {
    id: glyph
    anchors.centerIn: parent
    text: "󰌌"
    font.family: Style.fontFamily
    font.pixelSize: solidBar ? Style.barFontIcon : 15
    color: (chipMouse.containsMouse || popup.shouldShow)
      ? Style.sky
      : (solidBar && barHost ? barHost.barForeground : Style.text)
  }

  MouseArea {
    id: chipMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      popup.shouldShow = !popup.shouldShow
      if (popup.shouldShow) root.rebuild()
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
      implicitWidth: root.framePad * 2 + root.colW * 2 + root.colGap
      implicitHeight: Math.min(flick.contentHeight + root.framePad * 2, 720)

      Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: root.framePad
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: body
          width: flick.width
          spacing: 8

          Item {
            width: parent.width
            height: titleText.implicitHeight

            Text {
              id: titleText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "KEYBOARD SHORTCUTS"
              font { family: Style.fontFamily; pixelSize: 12; bold: true }
              color: Style.text
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.sourceLabel
              font { family: Style.fontFamily; pixelSize: 10; bold: true }
              color: Style.textMuted
            }
          }

          Text {
            visible: root.leftCol.length === 0 && root.rightCol.length === 0
            width: parent.width
            text: "No Hyprland bindings found."
            color: Style.textMuted
            font { family: Style.fontFamily; pixelSize: 12 }
            horizontalAlignment: Text.AlignHCenter
          }

          Row {
            visible: root.leftCol.length > 0 || root.rightCol.length > 0
            width: parent.width
            spacing: root.colGap

            Column {
              width: root.colW
              spacing: 0
              Repeater {
                model: root.leftCol
                ShortcutRow {
                  required property var modelData
                  width: root.colW
                  row: modelData
                  descW: root.descW
                  keyW: root.keyW
                }
              }
            }

            Column {
              width: root.colW
              spacing: 0
              Repeater {
                model: root.rightCol
                ShortcutRow {
                  required property var modelData
                  width: root.colW
                  row: modelData
                  descW: root.descW
                  keyW: root.keyW
                }
              }
            }
          }
        }
      }
    }
  }

  component ShortcutRow: Item {
    property var row: ({})
    property int descW: 244
    property int keyW: 100
    readonly property bool isHeader: row && row.kind === "header"
    width: descW + keyW
    height: isHeader ? (20 + (Number(row.gap) || 0)) : 19

    Text {
      visible: isHeader
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 2
      text: (row && row.text) || ""
      font { family: Style.fontFamily; pixelSize: 10; bold: true }
      color: Style.sky
    }
    Text {
      visible: !isHeader
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: descW
      text: (row && row.desc) || ""
      font { family: Style.fontFamily; pixelSize: 12 }
      color: Style.text
      elide: Text.ElideRight
    }
    Text {
      visible: !isHeader
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: keyW
      text: (row && row.keys) || ""
      font { family: Style.fontFamily; pixelSize: 11; bold: true }
      color: Style.textMuted
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }
  }
}
