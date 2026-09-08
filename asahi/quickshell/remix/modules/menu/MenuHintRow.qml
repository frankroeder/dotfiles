import QtQuick
import QtQuick.Layouts
import "../../"

RowLayout {
  id: root
  property string hints: ""
  property real fontScale: 1.0
  property string fontFamily: Style.menuMono
  property bool gridNav: false

  spacing: 8
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
        color: Style.menuControlBg
        border.width: 1
        border.color: Style.menuHairline
        Text {
          id: keyLbl
          anchors.centerIn: parent
          text: modelData.key
          color: Style.menuAccent
          font.pixelSize: 10 * root.fontScale
          font.family: root.fontFamily
        }
      }
      Text {
        text: modelData.label
        color: Style.menuInkMuted
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
    Layout.alignment: Qt.AlignVCenter
  }

  Item { Layout.fillWidth: true }
}
