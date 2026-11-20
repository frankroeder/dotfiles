import QtQuick
import "../../"

// Running-app dots (idea: shell-ninja/hyprconf dock): one per open window, at most 3; the focused app's first dot
// stretches into an accent pill with a soft halo (OutBack, once per change; nothing loops).
Row {
  id: root
  property int count: 0
  property bool active: false
  spacing: 3
  visible: root.count > 0
  Repeater {
    model: Math.min(3, root.count)
    Rectangle {
      required property int index
      readonly property bool lead: index === 0 && root.active
      width: lead ? 16 : 5
      height: 4
      radius: 2
      color: lead ? Style.m3primary : Qt.alpha(Style.m3onSurface, index === 0 ? 0.78 : 0.45)
      Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
      Rectangle {
        visible: parent.lead
        anchors.centerIn: parent
        width: parent.width + 6
        height: parent.height + 4
        radius: height / 2
        z: -1
        color: Qt.alpha(Style.m3primary, 0.28)
      }
    }
  }
}
