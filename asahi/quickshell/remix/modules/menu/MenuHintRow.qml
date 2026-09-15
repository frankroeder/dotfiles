import QtQuick
import QtQuick.Layouts
import "../../"

RowLayout {
  id: root
  property string hints: ""
  property real fontScale: 1.0
  property string fontFamily: Style.menuMono
  property bool gridNav: false

  spacing: 10
  implicitHeight: Math.round(20 * root.fontScale)

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
        width: keyLbl.width + Math.round(10 * root.fontScale)
        height: Math.round(18 * root.fontScale)
        radius: Style.radiusSm
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Style.menuNeon, 0.4)
        Text {
          id: keyLbl
          anchors.centerIn: parent
          text: modelData.key
          color: Style.menuNeon
          font.pixelSize: 10 * root.fontScale
          font.family: root.fontFamily
        }
      }
      Text {
        text: modelData.label
        color: Style.menuInkMuted
        font.pixelSize: 10 * root.fontScale
        font.family: root.fontFamily
        font.letterSpacing: 0.3
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Text {
    visible: root.hints !== ""
    text: root.hints
    color: Style.menuInkMuted
    font.pixelSize: 10 * root.fontScale
    font.family: root.fontFamily
    font.letterSpacing: 0.3
    Layout.alignment: Qt.AlignVCenter
  }

  Item { Layout.fillWidth: true }
}
