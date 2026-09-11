import QtQuick
import "../../"
import "components" as BarComponents

// Flat bar control — inset hover pill + optional tooltip.
Item {
  id: root

  property var barHost: null
  property string text: ""
  property string icon: ""
  property string fontFamily: Style.fontFamily
  property real fontSize: Style.barFontBody
  property real iconSize: Style.barFontGlyph
  property color foreground: barHost ? barHost.barForeground : Style.barStripText
  property color activeColor: Style.red
  property bool active: false
  property real horizontalMargin: 8
  property real verticalPadding: 4
  property real fixedWidth: -1
  property real fixedHeight: -1
  property bool keepSpace: false
  property bool dimmed: false
  property bool concealed: false
  property bool interactive: true
  property bool pressable: true
  property bool useActiveColor: true
  property bool labelVisible: true
  property bool hasVisualContent: text !== "" || icon !== ""
  property string tooltipText: ""

  signal pressed(int button)
  signal wheelMoved(int delta)

  function triggerPress(button) {
    root.pressed(button)
  }

  readonly property int barSize: barHost ? barHost.barSize : Style.barHeight
  readonly property real scaledHorizontalMargin: horizontalMargin
  readonly property real scaledVerticalPadding: verticalPadding
  readonly property real labelWidth: contentRow.implicitWidth

  visible: hasVisualContent || keepSpace
  opacity: !hasVisualContent || concealed ? 0 : (dimmed ? 0.45 : 1)
  implicitWidth: fixedWidth > 0 ? fixedWidth : Math.max(12, contentRow.implicitWidth + scaledHorizontalMargin * 2)
  implicitHeight: fixedHeight > 0 ? fixedHeight : Math.max(barSize, contentRow.implicitHeight + scaledVerticalPadding * 2)

  Behavior on opacity {
    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
  }

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: Style.barChipInset
    anchors.bottomMargin: Style.barChipInset
    radius: Style.radiusSm
    color: mouseArea.containsMouse && root.interactive ? Style.barStripHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Row {
    id: contentRow
    anchors.centerIn: parent
    spacing: 4
    readonly property real lineH: Math.max(
      root.icon !== "" ? root.iconSize : 0,
      root.labelVisible && root.text !== "" ? root.fontSize : 0
    )

    Text {
      visible: root.icon !== ""
      height: contentRow.lineH
      text: root.icon
      color: root.active && root.useActiveColor ? root.activeColor : root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.iconSize
      renderType: Text.NativeRendering
      verticalAlignment: Text.AlignVCenter
    }

    Text {
      id: label
      visible: root.labelVisible && root.text !== ""
      height: contentRow.lineH
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

  BarComponents.TooltipWindow {
    target: root
    text: root.tooltipText
    show: mouseArea.containsMouse && root.tooltipText !== ""
  }
}
