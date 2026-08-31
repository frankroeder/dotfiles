import QtQuick
import QtQuick.Layouts
import "../../"

// Launcher-matching list row (adaptive height, seal accent, accessory column).
Item {
  id: row
  property string icon: ""
  property string title: ""
  property string accessory: ""
  property bool selected: false
  property string uiFont: Style.fontFamily
  property var onClicked: null

  implicitHeight: 40
  height: 40
  width: parent ? parent.width : implicitWidth

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: 2
    anchors.rightMargin: 2
    anchors.topMargin: 1
    anchors.bottomMargin: 1
    radius: Style.radiusSm
    color: row.selected ? Style.menuRowSel : (rowMa.containsMouse ? Style.menuRowHi : "transparent")
    Behavior on color { ColorAnimation { duration: 50 } }
  }
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: 6
    anchors.bottomMargin: 6
    width: 2
    radius: 1
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
      font.weight: row.selected ? Font.Medium : Font.Normal
      font.letterSpacing: 0.6
      elide: Text.ElideRight
    }
    Text {
      visible: row.accessory !== ""
      text: row.accessory.toUpperCase()
      color: row.selected ? Style.menuSeal : Style.menuInkDeep
      opacity: row.selected ? 0.95 : 0.65
      font.pixelSize: 10
      font.family: row.uiFont
      font.letterSpacing: 1.5
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
