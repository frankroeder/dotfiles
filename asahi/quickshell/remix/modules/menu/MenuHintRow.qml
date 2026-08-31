import QtQuick
import QtQuick.Layouts
import "../../"

RowLayout {
  id: root
  property string hints: ""
  property real fontScale: 1.0
  property string fontFamily: Style.menuMono
  property bool gridNav: false

  spacing: 12
  implicitHeight: Math.round(20 * root.fontScale)

  Repeater {
    model: [
      { key: root.gridNav ? "hjkl / ←→" : "↑↓", label: "navigate" },
      { key: "⏎", label: "launch" },
      { key: "esc", label: "close" }
    ]
    delegate: Row {
      spacing: 5
      required property var modelData

      Rectangle {
        width: keyLbl.width + Math.round(10 * root.fontScale)
        height: Math.round(20 * root.fontScale)
        radius: Math.round(6 * root.fontScale)
        color: Style.menuControlBg
        border.width: 1
        border.color: Style.menuSep
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
    color: Style.menuInkMuted
    font.pixelSize: 10 * root.fontScale
    font.family: root.fontFamily
    font.letterSpacing: 1.2
    Layout.alignment: Qt.AlignVCenter
  }

  Item { Layout.fillWidth: true }
}
