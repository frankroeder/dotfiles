import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels
import "../launcher_layout.js" as LauncherGeom

// Screenshots / recordings gallery pane (M3 caelestia look).
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  id: shotsPane
  property var root
  anchors.fill: parent
  readonly property bool videoMode: root.galleryKind === "videos"
  readonly property var items: shotsPane.videoMode ? (root.videos || []) : (root.shots || [])

  // Full-round pill: segmented tab (selected) or action button.
  component Pill: Rectangle {
    property string icon
    property string label
    property bool selected: false
    property color bg: Style.m3container
    property color fg: Style.m3onSurface
    signal clicked()
    implicitWidth: pillRow.implicitWidth + 24; implicitHeight: 32
    radius: Style.menuRadiusFull
    color: selected ? Style.m3secondaryContainer : (pma.containsMouse ? Qt.lighter(bg, 1.15) : bg)
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: pillRow; anchors.centerIn: parent; spacing: 7
      Text {
        text: parent.parent.icon; color: parent.parent.fg; font.family: root.uiFont; font.pixelSize: root.fontPx(12)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
        font.weight: parent.parent.selected ? Font.DemiBold : Font.Medium; anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  // Small round icon button floating over a thumbnail.
  component IconBtn: Rectangle {
    property string icon
    property color tone: Style.m3onSurface
    signal clicked()
    width: 28; height: 28; radius: 14
    color: ima.containsMouse ? Style.m3containerHigh : Style.m3surface
    Behavior on color { ColorAnimation { duration: 120 } }
    Text { anchors.centerIn: parent; text: parent.icon; color: parent.tone; font.family: root.uiFont; font.pixelSize: root.fontPx(12) }
    MouseArea {
      id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onClicked: (mouse) => { mouse.accepted = true; parent.clicked() }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Segmented Shots / Videos switch, capture pills on the right.
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Rectangle {
        implicitWidth: segRow.implicitWidth + 8; implicitHeight: 40
        radius: Style.menuRadiusFull; color: Style.m3container
        Row {
          id: segRow; anchors.centerIn: parent; spacing: 4
          Pill { icon: "󰹑"; label: "Shots " + (root.shots || []).length; selected: !shotsPane.videoMode; onClicked: root.galleryKind = "shots" }
          Pill { icon: "󰕧"; label: "Videos " + (root.videos || []).length; selected: shotsPane.videoMode; onClicked: root.galleryKind = "videos" }
        }
      }
      Item { Layout.fillWidth: true }
      Pill {
        icon: "󰄀"; label: "Smart"
        onClicked: { Quickshell.execDetached([root.binDir + "/asahi-cmd-screenshot", "smart"]); Qt.callLater(root.scanShots) }
      }
      Pill {
        icon: "󰩬"; label: "Capture"; bg: Style.m3primaryContainer
        onClicked: { Quickshell.execDetached([root.binDir + "/asahi-cmd-screenshot", "region"]); Qt.callLater(root.scanShots) }
      }
    }

    // Gallery card.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.menuPanelRadius
      color: Style.m3container

      GridView {
        id: shotGrid
        anchors.fill: parent
        anchors.margins: 8
        visible: shotsPane.items.length > 0
        rightMargin: 10
        cellWidth: Math.max(1, Math.floor((width - rightMargin) / 3))
        cellHeight: Math.round(cellWidth * 0.62) + 8
        clip: true
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Menu.MenuScrollBar {}
        model: shotsPane.items

        delegate: Item {
          id: cell
          required property var modelData
          required property int index
          readonly property bool copied: root.copiedShot === modelData.path
          width: shotGrid.cellWidth
          height: shotGrid.cellHeight

          ClippingRectangle {
            id: tile
            anchors.fill: parent
            anchors.margins: 4
            radius: Style.menuRadiusMd
            color: Style.m3containerHigh
            HoverHandler { id: tileHover }
            scale: tileHover.hovered ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Image {
              anchors.fill: parent
              visible: !shotsPane.videoMode
              source: !shotsPane.videoMode && modelData.path ? ("file://" + modelData.path) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize.width: 480
              sourceSize.height: 300
              // Fade in once decoded instead of popping in tile by tile.
              opacity: status === Image.Ready ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            Rectangle {
              visible: shotsPane.videoMode
              anchors.centerIn: parent
              width: 44; height: 44; radius: 22
              color: Style.m3primaryContainer
              Text { anchors.centerIn: parent; text: "󰐊"; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(18) }
            }

            // Bottom label strip.
            Rectangle {
              anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
              height: shotLbl.implicitHeight + 10
              color: Style.m3surface
              opacity: 0.92
              Text {
                id: shotLbl
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                text: modelData.label
                color: Style.m3onSurface
                font.family: root.uiSans; font.pixelSize: root.fontPx(8)
                elide: Text.ElideMiddle
                verticalAlignment: Text.AlignVCenter
              }
            }

            // Copied feedback.
            Rectangle {
              anchors.fill: parent
              color: Style.m3surface
              opacity: cell.copied ? 0.55 : 0
              Behavior on opacity { NumberAnimation { duration: 140 } }
            }
            Rectangle {
              anchors.centerIn: parent
              visible: cell.copied
              implicitWidth: copiedRow.implicitWidth + 24; implicitHeight: 30
              radius: Style.menuRadiusFull; color: Style.green
              Row {
                id: copiedRow; anchors.centerIn: parent; spacing: 6
                Text {
                  text: "󰄬"; color: Style.m3onPrimary; font.family: root.uiFont; font.pixelSize: root.fontPx(12)
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "Copied"; color: Style.m3onPrimary; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
                  font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            MouseArea {
              id: hma
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: (mouse) => {
                if (shotsPane.videoMode) root.openShot(modelData.path)
                else if (mouse.button === Qt.RightButton) root.previewShot(modelData.path)
                else root.copyShot(modelData.path)
              }
            }

            // Hover actions: preview / copy / open / delete.
            // Tile HoverHandler (not hma.containsMouse): IconBtn MouseAreas steal
            // the tile MouseArea hover, which hid the row while clicks still hit.
            Row {
              id: shotHoverActions
              anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
              spacing: 4
              opacity: tileHover.hovered ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 120 } }
              IconBtn { visible: !shotsPane.videoMode; icon: "󰋲"; onClicked: root.previewShot(cell.modelData.path) }
              IconBtn { visible: !shotsPane.videoMode; icon: "󰆏"; onClicked: root.copyShot(cell.modelData.path) }
              IconBtn { icon: "󰏌"; onClicked: root.openShot(cell.modelData.path) }
              IconBtn { icon: "󰆴"; tone: Style.red; onClicked: root.deleteShot(cell.modelData.path) }
            }
          }
          // Outline on hover / copied.
          Rectangle {
            anchors.fill: tile
            radius: tile.radius
            scale: tile.scale
            color: "transparent"
            border.width: cell.copied ? 2 : 1
            border.color: cell.copied ? Style.green : (tileHover.hovered ? Style.m3outline : Style.m3outlineVariant)
            Behavior on border.color { ColorAnimation { duration: 120 } }
          }
        }
      }

      // Empty state.
      ColumnLayout {
        anchors.centerIn: parent
        visible: shotsPane.items.length === 0
        spacing: 10
        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: 76; height: 76; radius: Style.menuRadiusLg
          color: Style.m3primaryContainer
          Text {
            anchors.centerIn: parent; text: shotsPane.videoMode ? "󰕧" : "󰹑"; color: Style.m3primary
            font.family: root.uiFont; font.pixelSize: 38
          }
        }
        Text {
          Layout.alignment: Qt.AlignHCenter
          text: shotsPane.videoMode ? "No recordings yet" : "No screenshots yet"
          color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(14); font.weight: Font.DemiBold
        }
        Text {
          Layout.alignment: Qt.AlignHCenter
          text: shotsPane.videoMode ? "Recordings from the bar land in ~/Videos" : "Capture one above · saved to ~/screenshots"
          color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
        }
      }
    }

    Text {
      Layout.fillWidth: true
      text: shotsPane.videoMode ? "Click opens  ·  󰆴 deletes" : "Click copies  ·  right-click previews"
      color: Style.m3onSurfaceVariant
      font.family: root.uiSans; font.pixelSize: root.fontPx(9)
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
