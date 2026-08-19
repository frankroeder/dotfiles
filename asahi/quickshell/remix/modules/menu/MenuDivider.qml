import QtQuick
import "../../"

Rectangle {
  implicitWidth: parent ? parent.width : 0
  implicitHeight: 1
  width: parent ? parent.width : implicitWidth
  height: implicitHeight
  color: Style.menuSep
}