import QtQuick
import QtQuick.Layouts
import "../../"

// Launcher-matching sidebar / list row (38px, seal accent bar).
Item {
  id: row
  property var modelData: null
  required property bool isActive
  property var onActivate: null

  Layout.fillWidth: true
  implicitWidth: 200
  implicitHeight: 38
  width: parent ? parent.width : implicitWidth
  height: 38

  Rectangle {
    anchors.fill: parent
    color: row.isActive ? Style.menuRowSel : (rowMa.containsMouse ? Style.menuRowHi : Style.menuCardBg)
    Behavior on color { ColorAnimation { duration: 40 } }
  }
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 2
    color: Style.menuSeal
    visible: row.isActive
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 10
    spacing: 10

    Text {
      text: row.modelData ? (row.modelData.icon ?? "") : ""
      font.pixelSize: 14
      color: row.isActive ? Style.menuSeal : Style.menuInkDeep
      font.family: row.uiFont
      Layout.preferredWidth: 18
      horizontalAlignment: Text.AlignHCenter
    }
    Text {
      Layout.fillWidth: true
      text: row.modelData ? (row.modelData.label ?? "") : ""
      font.pixelSize: 13
      font.weight: row.isActive ? Font.Medium : Font.Light
      color: row.isActive ? Style.menuInk : Style.menuInkDeep
      font.family: row.uiFont
      font.letterSpacing: 1
      elide: Text.ElideRight
    }
  }

  property string uiFont: "Hack Nerd Font"

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
