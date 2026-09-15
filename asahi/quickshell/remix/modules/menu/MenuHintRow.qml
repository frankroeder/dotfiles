import QtQuick
import QtQuick.Layouts
import "../../"

RowLayout {
  id: root
  property string hints: ""
  property real fontScale: 1.0
  property string fontFamily: Style.menuSans
  property bool gridNav: false

  spacing: 10
  implicitHeight: Math.round(22 * root.fontScale)

  Repeater {
    model: [
      { key: root.gridNav ? "hjkl" : "↑↓", label: "navigate" },
      { key: "⏎", label: "open" },
      { key: "esc", label: "close" }
    ]
    delegate: Row {
      required property var modelData
      spacing: 6

      Rectangle {
        width: keyLbl.width + Math.round(12 * root.fontScale)
        height: Math.round(20 * root.fontScale)
        radius: height / 2
        color: Style.m3containerHigh
        Text {
          id: keyLbl
          anchors.centerIn: parent
          text: modelData.key
          color: Style.m3onSurface
          font.pixelSize: 10 * root.fontScale
          font.family: root.fontFamily
          font.weight: Font.Medium
        }
      }
      Text {
        text: modelData.label
        color: Style.m3onSurfaceVariant
        font.pixelSize: 11 * root.fontScale
        font.family: root.fontFamily
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Text {
    visible: root.hints !== ""
    text: root.hints
    color: Style.m3outline
    font.pixelSize: 11 * root.fontScale
    font.family: root.fontFamily
    Layout.alignment: Qt.AlignVCenter
  }

  Item { Layout.fillWidth: true }
}
