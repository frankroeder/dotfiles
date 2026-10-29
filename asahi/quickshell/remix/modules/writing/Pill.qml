import QtQuick
import "../../"

// Footer / mode pill (WritingTools, LookupView).
Rectangle {
  id: pill
  property string icon: ""
  property string label: ""
  property string keyHint: ""
  property bool primary: false
  property bool active: false
  signal clicked()
  implicitWidth: pillRow.implicitWidth + 26
  implicitHeight: 34
  radius: height / 2
  opacity: enabled ? 1 : 0.4
  color: primary ? (pillMa.containsMouse ? Qt.lighter(Style.m3primary, 1.08) : Style.m3primary)
    : active ? Style.m3primaryContainer
    : pillMa.containsMouse ? Style.m3containerHigh : Style.m3container
  border.width: active ? 1 : 0
  border.color: Style.menuSelBorder
  Behavior on color { ColorAnimation { duration: 120 } }
  Row {
    id: pillRow
    anchors.centerIn: parent
    spacing: 7
    Text {
      visible: pill.icon !== ""
      text: pill.icon
      color: pill.primary ? Style.m3onPrimary : pill.active ? Style.m3primary : Style.m3onSurface
      font.family: Style.menuMono; font.pixelSize: 15
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: pill.label
      color: pill.primary ? Style.m3onPrimary : Style.m3onSurface
      font.family: Style.menuSans; font.pixelSize: 13; font.weight: Font.DemiBold
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      visible: pill.keyHint !== ""
      text: pill.keyHint
      color: pill.primary ? Qt.alpha(Style.m3onPrimary, 0.7) : Style.m3onSurfaceVariant
      font.family: Style.menuSans; font.pixelSize: 11
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  MouseArea {
    id: pillMa
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pill.clicked()
  }
}
