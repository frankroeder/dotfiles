import QtQuick
import "../../"

// Segmented control: segments on a container track, one selection handle that slides to `current` with its edges
// apart (MenuStretchPill, horizontal: the leading edge on the spring, the trailing one 1.5× slower). Segments have
// the shared hover / press layers and ripple. `model`: [{ label, icon }]; `activated(index)`: the owner sets `current`.
Rectangle {
  id: seg
  property var model: []
  property int current: 0
  property real fontScale: Style.uiScale
  property int segHeight: Math.round(28 * seg.fontScale)
  property int labelPx: Math.round(11 * seg.fontScale)
  signal activated(int index)

  implicitWidth: segRow.implicitWidth + 8
  implicitHeight: seg.segHeight + 8
  radius: height / 2
  color: Style.m3container

  readonly property Item cur: segRep.count > seg.current && seg.current >= 0 ? segRep.itemAt(seg.current) : null
  Rectangle {
    id: handle
    readonly property real targetLeft: seg.cur ? segRow.x + seg.cur.x : 0
    readonly property real targetRight: seg.cur ? segRow.x + seg.cur.x + seg.cur.width : 0
    property real edgeLeft: targetLeft
    property real edgeRight: targetRight
    visible: !!seg.cur
    x: edgeLeft; y: 4
    width: Math.max(0, edgeRight - edgeLeft); height: seg.segHeight
    radius: height / 2
    color: Style.menuSelFill
    border.width: 1; border.color: Style.menuSelBorder
    // At the start the edge still holds its old value: moving right, the left edge trails; moving left, the right one.
    // No motion while the row is first laid out (width 0).
    Behavior on edgeLeft {
      enabled: handle.width > 0
      MenuAnim { duration: Style.menuSpringMs * (handle.targetLeft > handle.edgeLeft ? 1.5 : 1) }
    }
    Behavior on edgeRight {
      enabled: handle.width > 0
      MenuAnim { duration: Style.menuSpringMs * (handle.targetRight < handle.edgeRight ? 1.5 : 1) }
    }
  }
  Row {
    id: segRow
    anchors.centerIn: parent
    spacing: 2
    Repeater {
      id: segRep
      model: seg.model
      Item {
        id: segItem
        required property var modelData
        required property int index
        readonly property bool on: index === seg.current
        implicitWidth: segInner.implicitWidth + Math.round(22 * seg.fontScale)
        implicitHeight: seg.segHeight
        scale: segMa.pressed && !Style.reduceMotion ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: Style.menuStateMs; easing.type: Easing.OutCubic } }
        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: segMa.pressed ? Style.m3statePress : Style.m3stateHover
          opacity: segMa.containsMouse || segMa.pressed ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
        }
        MenuRipple { id: segRipple; radius: height / 2 }
        Row {
          id: segInner
          anchors.centerIn: parent
          spacing: Math.round(5 * seg.fontScale)
          Text {
            visible: !!segItem.modelData.icon
            anchors.verticalCenter: parent.verticalCenter
            text: segItem.modelData.icon || ""
            color: segItem.on ? Style.m3primary : Style.m3onSurfaceVariant
            font.family: Style.menuMono; font.pixelSize: Math.round(12 * seg.fontScale)
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: segItem.modelData.label
            textFormat: Text.PlainText
            color: segItem.on ? Style.m3primary : Style.m3onSurface
            font.family: Style.menuSans; font.pixelSize: seg.labelPx
            font.weight: segItem.on ? Font.DemiBold : Font.Medium
          }
        }
        MouseArea {
          id: segMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPressed: mouse => segRipple.start(mouse.x, mouse.y)
          onReleased: segRipple.release()
          onCanceled: segRipple.release()
          onClicked: seg.activated(segItem.index)
        }
      }
    }
  }
}
