import QtQuick
import "../../"

// Flat bar control — omarchy WidgetButton adapted for Asahi Style tokens.
Item {
  id: root

  property var barHost: null
  property string text: ""
  property string fontFamily: Style.fontFamily
  property real fontSize: Style.barFontBody
  property color foreground: barHost ? barHost.barForeground : Style.barStripText
  property color activeColor: Style.red
  property bool active: false
  property real horizontalMargin: 7
  property real verticalPadding: 5
  property real fixedWidth: -1
  property real fixedHeight: -1
  property bool keepSpace: false
  property bool dimmed: false
  property bool concealed: false
  property bool interactive: true
  property bool pressable: true
  property bool useActiveColor: true
  property bool labelVisible: true
  property bool hasVisualContent: text !== ""
  property string tooltipText: ""

  signal pressed(int button)
  signal wheelMoved(int delta)

  function triggerPress(button) {
    root.pressed(button)
  }

  readonly property int barSize: barHost ? barHost.barSize : Style.barHeight
  readonly property real scaledHorizontalMargin: horizontalMargin
  readonly property real scaledVerticalPadding: verticalPadding
  readonly property real labelWidth: label.visible ? label.implicitWidth : 0

  visible: hasVisualContent || keepSpace
  opacity: !hasVisualContent || concealed ? 0 : (dimmed ? 0.45 : 1)
  implicitWidth: fixedWidth > 0 ? fixedWidth : Math.max(12, label.implicitWidth + scaledHorizontalMargin * 2)
  implicitHeight: fixedHeight > 0 ? fixedHeight : Math.max(barSize, label.implicitHeight + scaledVerticalPadding * 2)

  Behavior on opacity {
    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
  }

  Text {
    id: label
    visible: root.labelVisible
    anchors.centerIn: parent
    text: root.text
    color: root.active && root.useActiveColor ? root.activeColor : root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
      ColorAnimation { duration: 160 }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    enabled: root.interactive
    hoverEnabled: true
    cursorShape: root.pressable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: function(mouse) { if (root.pressable) root.triggerPress(mouse.button) }
    onWheel: function(wheel) { root.wheelMoved(wheel.angleDelta.y) }
  }
}
