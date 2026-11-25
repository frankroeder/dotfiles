import QtQuick
import "../../"

// Divider line: one device pixel (0.5 px at scale 2, 0.53 at 1.875); not antialiased, so it covers exactly one pixel
// row. Layouts round an item's height up to 1 px: the line sits inside an item they may size freely.
Item {
  implicitWidth: parent ? parent.width : 0
  implicitHeight: 1 / Screen.devicePixelRatio
  width: parent ? parent.width : implicitWidth
  height: implicitHeight
  Rectangle { width: parent.width; height: 1 / Screen.devicePixelRatio; color: Style.m3outlineVariant }
}
