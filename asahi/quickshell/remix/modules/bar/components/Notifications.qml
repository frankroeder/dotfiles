import QtQuick
import QtQuick.Layouts
import "../../../"

// Bell right of the notch (BarHost: notifNotch / notifBlock; the left belongs to media): click =
// history sheet (top-right), right-click = do not disturb. Unread count since the sheet last toggled.
Item {
  id: root

  property var notificationCenter: null
  readonly property bool dnd: !!root.notificationCenter && root.notificationCenter.dndEnabled
  readonly property int unread: root.notificationCenter ? root.notificationCenter.unreadCount : 0

  visible: root.notificationCenter !== null
  implicitWidth: notifRow.implicitWidth + 12
  implicitHeight: Style.barHeight

  RowLayout {
    id: notifRow
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.dnd ? "󰂛" : (root.unread > 0 ? "󰂞" : "󰂚")
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyph
      color: root.dnd ? Style.yellow : Style.blueAlt
    }

    Rectangle {
      visible: root.unread > 0
      implicitWidth: Math.max(18, countText.implicitWidth + 10)
      implicitHeight: 18
      radius: 9
      color: root.dnd ? Qt.alpha(Style.yellow, 0.22) : Style.m3primaryContainer
      Text {
        id: countText
        anchors.centerIn: parent
        text: root.unread > 99 ? "99+" : root.unread
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontCaption
        font.bold: true
        color: Style.barStripText
      }
    }
  }

  HoverTint { lit: chipMouse.containsMouse || (!!root.notificationCenter && root.notificationCenter.historyVisible) }
  MouseArea {
    id: chipMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (!root.notificationCenter) return
      if (mouse.button === Qt.RightButton) root.notificationCenter.toggleDnd()
      else root.notificationCenter.toggleHistory()
    }
  }
}
