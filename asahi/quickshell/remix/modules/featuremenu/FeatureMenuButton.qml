import QtQuick
import QtQuick.Layouts
import "../../"

Rectangle {
  id: btn
  property string icon: ""
  property string label: ""
  property bool danger: false
  property var onClick: null
  property string fontFamily: "Hack Nerd Font"

  Layout.fillWidth: true
  Layout.preferredWidth: implicitWidth
  Layout.preferredHeight: 42
  implicitHeight: 42
  radius: Style.menuRadius
  color: ma.containsMouse
    ? (danger ? Qt.rgba(Style.red.r, Style.red.g, Style.red.b, 0.18) : Style.menuRowHi)
    : Style.menuControlBg
  border.color: ma.containsMouse ? (danger ? Style.red : Style.menuSep) : Style.menuSep
  border.width: 1

  RowLayout {
    anchors.centerIn: parent
    spacing: 8
    Text {
      text: btn.icon
      font.pixelSize: 15
      color: danger ? Style.red : Style.menuSeal
      font.family: btn.fontFamily
    }
    Text {
      text: btn.label
      font.pixelSize: 12
      color: Style.menuInk
      font.family: btn.fontFamily
      font.letterSpacing: 0.5
    }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (btn.onClick) btn.onClick()
  }
}
