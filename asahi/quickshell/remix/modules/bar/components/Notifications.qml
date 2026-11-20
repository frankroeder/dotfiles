import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../menu" as Menu

// Bell right of the notch (BarHost: notifNotch / notifBlock; the left belongs to media): click =
// history sheet (top-right), right-click = do not disturb. Unread count since the sheet last toggled.
Item {
  id: root

  property var notificationCenter: null
  readonly property bool dnd: !!root.notificationCenter && root.notificationCenter.dndEnabled
  readonly property int unread: root.notificationCenter ? root.notificationCenter.unreadCount : 0

  visible: root.notificationCenter !== null

  // A new notification: the bell swings once from its top and the badge pops (one-shot, event-driven, no loop;
  // quiet under Do Not Disturb). The count drops when the sheet toggles: no cue then.
  property int seenUnread: 0
  onUnreadChanged: {
    if (root.unread > root.seenUnread && !root.dnd && root.visible) nudge.restart()
    root.seenUnread = root.unread
  }
  ParallelAnimation {
    id: nudge
    SequentialAnimation {
      NumberAnimation { target: bell; property: "rotation"; to: 14; duration: 90; easing.type: Easing.OutQuad }
      NumberAnimation { target: bell; property: "rotation"; to: -10; duration: 140; easing.type: Easing.InOutQuad }
      NumberAnimation { target: bell; property: "rotation"; to: 5; duration: 120; easing.type: Easing.InOutQuad }
      NumberAnimation { target: bell; property: "rotation"; to: 0; duration: 150; easing.type: Easing.OutQuad }
    }
    Menu.MenuAnim { target: badge; property: "scale"; from: 0.6; to: 1 }
  }
  implicitWidth: notifRow.implicitWidth + 6
  implicitHeight: Style.barHeight

  RowLayout {
    id: notifRow
    anchors.centerIn: parent
    spacing: 4

    Text {
      id: bell
      transformOrigin: Item.Top
      text: root.dnd ? "󰂛" : (root.unread > 0 ? "󰂞" : "󰂚")
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyph
      color: root.dnd ? Style.yellow : Style.blueAlt
      Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
    }

    Rectangle {
      id: badge
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

  HoverTint { down: chipMouse.pressed; lit: chipMouse.containsMouse || (!!root.notificationCenter && root.notificationCenter.historyVisible) }
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
