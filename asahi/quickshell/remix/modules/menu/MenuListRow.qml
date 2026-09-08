import QtQuick
import QtQuick.Layouts
import "../../"

Item {
  id: row
  property string icon: ""
  property string title: ""
  property string accessory: ""
  property bool selected: false
  property string uiFont: Style.menuMono
  property string labelFamily: Style.menuSans
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
    border.width: 0
    Behavior on color { ColorAnimation { duration: 60 } }
  }

  Rectangle {
    visible: row.selected
    width: Style.menuRail
    height: parent.height - 12
    radius: 1
    color: Style.menuAccent
    anchors.left: parent.left
    anchors.leftMargin: 4
    anchors.verticalCenter: parent.verticalCenter
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 14
    spacing: 12

    Text {
      text: row.icon
      font.pixelSize: 14
      color: row.selected ? Style.menuInk : Style.menuInkDeep
      font.family: row.uiFont
      Layout.preferredWidth: 18
      horizontalAlignment: Text.AlignHCenter
    }
    Text {
      Layout.fillWidth: true
      text: row.title
      color: row.selected ? Style.menuInk : Style.menuInk
      font.pixelSize: 13
      font.family: row.labelFamily
      font.weight: row.selected ? Font.Medium : Font.Normal
      font.letterSpacing: 0.15
      elide: Text.ElideRight
    }
    Text {
      visible: row.accessory !== ""
      text: row.accessory === "›" ? "›" : row.accessory
      color: row.selected ? Style.menuInkDeep : Style.menuInkMuted
      opacity: row.selected ? 0.9 : 0.55
      font.pixelSize: row.accessory === "›" ? 16 : 11
      font.family: row.labelFamily
      font.letterSpacing: 0.15
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
