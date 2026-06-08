import QtQuick
import QtQuick.Layouts
import "../../"

RowLayout {
  id: root
  property string hints: ""
  property real fontScale: 1.0
  property string fontFamily: Style.menuMono

  spacing: 14

  Repeater {
    model: [
      { key: "↑↓", label: "navigate" },
      { key: "⏎", label: "launch" },
      { key: "esc", label: "close" }
    ]
    delegate: Row {
      spacing: 4
      required property var modelData

      Rectangle {
        width: keyLbl.width + Math.round(8 * root.fontScale)
        height: Math.round(18 * root.fontScale)
        radius: Math.round(4 * root.fontScale)
        color: Style.panelControlBg
        Text {
          id: keyLbl
          anchors.centerIn: parent
          text: modelData.key
          color: Style.menuInk
          font.pixelSize: 10 * root.fontScale
          font.family: root.fontFamily
        }
      }
      Text {
        text: modelData.label
        color: Style.menuInkDeep
        font.pixelSize: 10 * root.fontScale
        font.family: root.fontFamily
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Text {
    visible: root.hints !== ""
    text: root.hints
    color: Style.menuInkDeep
    font.pixelSize: 10 * root.fontScale
    font.family: root.fontFamily
    font.letterSpacing: 1
    Layout.alignment: Qt.AlignVCenter
  }

  Item { Layout.fillWidth: true }
}