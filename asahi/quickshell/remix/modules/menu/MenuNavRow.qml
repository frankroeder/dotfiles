import QtQuick
import QtQuick.Layouts
import "../../"

Item {
  id: row
  property var modelData: null
  required property bool isActive
  property var onActivate: null
  property string uiFont: Style.menuMono
  property string labelFamily: Style.menuSans

  Layout.fillWidth: true
  implicitWidth: 200
  implicitHeight: 38
  width: parent ? parent.width : implicitWidth
  height: 38

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: 2
    anchors.rightMargin: 2
    anchors.topMargin: 1
    anchors.bottomMargin: 1
    radius: Style.radiusSm
    color: row.isActive ? Style.menuRowSel : (rowMa.containsMouse ? Style.menuRowHi : "transparent")
    border.width: 0
    Behavior on color { ColorAnimation { duration: 60 } }
  }

  Rectangle {
    visible: row.isActive
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
    anchors.rightMargin: 10
    spacing: 10

    Text {
      text: row.modelData ? (row.modelData.icon ?? "") : ""
      font.pixelSize: 14
      color: row.isActive ? Style.menuInk : Style.menuInkDeep
      font.family: row.uiFont
      Layout.preferredWidth: 18
      horizontalAlignment: Text.AlignHCenter
    }
    Text {
      Layout.fillWidth: true
      text: row.modelData ? (row.modelData.label ?? "") : ""
      font.pixelSize: 13
      font.weight: row.isActive ? Font.Medium : Font.Normal
      color: row.isActive ? Style.menuInk : Style.menuInkDeep
      font.family: row.labelFamily
      font.letterSpacing: 0.15
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: rowMa
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      const item = row.modelData
      if (row.onActivate && item && item.key) row.onActivate(item)
    }
  }
}
