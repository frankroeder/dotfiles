import QtQuick
import QtQuick.Layouts
import "../../"

// Launcher-matching list row (38px, seal accent, accessory column).
Item {
  id: row
  property string icon: ""
  property string title: ""
  property string accessory: ""
  property bool selected: false
  property string uiFont: "Hack Nerd Font"
  property var onClicked: null

  implicitHeight: 38
  height: 38
  width: parent ? parent.width : implicitWidth

  Rectangle {
    anchors.fill: parent
    color: row.selected ? Style.menuRowSel : (rowMa.containsMouse ? Style.menuRowHi : Style.menuCardBg)
    Behavior on color { ColorAnimation { duration: 40 } }
  }
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 2
    color: Style.menuSeal
    visible: row.selected
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 12

    Text {
      text: row.icon
      font.pixelSize: 14
      color: row.selected ? Style.menuSeal : Style.menuInkDeep
      font.family: row.uiFont
      Layout.preferredWidth: 18
      horizontalAlignment: Text.AlignHCenter
    }
    Text {
      Layout.fillWidth: true
      text: row.title
      color: row.selected ? Style.menuInk : Style.menuInkDeep
      font.pixelSize: 13
      font.family: row.uiFont
      font.weight: row.selected ? Font.Medium : Font.Light
      font.letterSpacing: 1
      elide: Text.ElideRight
    }
    Text {
      visible: row.accessory !== ""
      text: row.accessory.toUpperCase()
      color: row.selected ? Style.menuSeal : Style.menuInkDeep
      opacity: row.selected ? 0.95 : 0.65
      font.pixelSize: 10
      font.family: row.uiFont
      font.letterSpacing: 2
      elide: Text.ElideLeft
      Layout.maximumWidth: 160
    }
  }

  MouseArea {
    id: rowMa
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (row.onClicked) row.onClicked()
  }
}
