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

// Storage pane: disks and home folder usage.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  property var root
  id: quickStorageRoot
  anchors.fill: parent
  property real diskRead: 0
  property real diskWrite: 0

  Process {
    id: ioProc
    command: [root.binDir + "/asahi-metrics"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(String(text || "").trim() || "{}")
          quickStorageRoot.diskRead = (data.disk && data.disk.read_bps) || 0
          quickStorageRoot.diskWrite = (data.disk && data.disk.write_bps) || 0
        } catch (e) {}
      }
    }
  }
  Timer {
    interval: 2000
    running: root.shouldShow && root.quickMode && root.quickPaneKey === "storage"
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!ioProc.running) ioProc.running = true
  }

  function mountColor(pct) {
    if (pct >= 90) return Style.red
    if (pct >= 75) return Style.orange
    return Style.m3secondary
  }

  // Hero disk: "/" (first highlight mount after sorting), the rest go to the list.
  readonly property var rootMount: {
    const m = root.storageMounts || []
    for (let i = 0; i < m.length; i++) if (m[i].mount === "/") return m[i]
    return m.length > 0 ? m[0] : null
  }
  readonly property var otherMounts: (root.storageMounts || []).filter(function(m) { return m !== quickStorageRoot.rootMount })

  Component.onCompleted: { Qt.callLater(root.scanStorage); listUsb() }

  // External disks (USB / hotplug): listed on open, then on udev block events while the launcher shows.
  property var usbDisks: []
  property string usbError: ""
  function listUsb() { if (!usbListProc.running) usbListProc.running = true }
  function usbAction(args) {
    if (usbActionProc.running) return
    quickStorageRoot.usbError = ""
    usbActionProc.command = [root.binDir + "/asahi-usb-storage"].concat(args)
    usbActionProc.running = true
  }
  function usbSpeed(mbps) {
    if (mbps >= 1000) return (mbps / 1000) + " Gb/s"
    return mbps > 0 ? mbps + " Mb/s" : ""
  }
  Process {
    id: usbListProc
    command: [root.binDir + "/asahi-usb-storage", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { quickStorageRoot.usbDisks = JSON.parse(String(text || "").trim() || "[]") } catch (e) {}
      }
    }
  }
  Process {
    // pdeathsig: udevadm dies with qs.
    command: ["setpriv", "--pdeathsig", "TERM", "udevadm", "monitor", "--udev", "--subsystem-match=block"]
    running: root.shouldShow
    stdout: SplitParser { onRead: usbDebounce.restart() }
  }
  Timer { id: usbDebounce; interval: 600; onTriggered: quickStorageRoot.listUsb() }
  Process {
    id: usbActionProc
    stderr: StdioCollector { onStreamFinished: quickStorageRoot.usbError = String(text || "").trim() }
    onExited: quickStorageRoot.listUsb()
  }

  // ---- M3 building blocks (caelestia look) ----
  component Pill: Rectangle {
    property string icon
    property string label
    property color bg: Style.m3containerHigh
    property color fg: Style.m3onSurface
    signal clicked()
    implicitWidth: pillRow.implicitWidth + 24
    implicitHeight: 32
    radius: Style.menuRadiusFull
    color: pillMa.containsMouse ? Qt.lighter(bg, 1.15) : bg
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: 6
      Text {
        visible: !!parent.parent.icon; text: parent.parent.icon; color: parent.parent.fg
        font.family: quickStorageRoot.root.uiFont; font.pixelSize: quickStorageRoot.root.fontPx(12); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.weight: Font.Medium
        font.family: quickStorageRoot.root.uiSans; font.pixelSize: quickStorageRoot.root.fontPx(10); anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  component Chip: Rectangle {
    property string icon
    property string label
    property color bg: Style.m3secondaryContainer
    property color fg: Style.m3onSurface
    implicitWidth: chipRow.implicitWidth + 20
    implicitHeight: 28
    radius: Style.menuRadiusFull
    color: bg
    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: 6
      Text {
        text: parent.parent.icon; color: parent.parent.fg
        font.family: quickStorageRoot.root.uiFont; font.pixelSize: quickStorageRoot.root.fontPx(11); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.weight: Font.Medium
        font.family: quickStorageRoot.root.uiSans; font.pixelSize: quickStorageRoot.root.fontPx(10); anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // Thin usage bar: containerHigh track, accent fill.
  component UsageBar: Rectangle {
    property real frac: 0
    property color accent: Style.m3secondary
    implicitHeight: 6
    radius: 3
    color: Style.m3containerHigh
    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, parent.frac))
      height: parent.height
      radius: parent.radius
      color: parent.accent
      Behavior on width { Menu.MenuAnim {} }
    }
  }

  component CardTitle: Text {
    color: Style.m3onSurface
    font.family: quickStorageRoot.root.uiSans
    font.pixelSize: quickStorageRoot.root.fontPx(12)
    font.weight: Font.DemiBold
  }
  component Secondary: Text {
    color: Style.m3onSurfaceVariant
    font.family: quickStorageRoot.root.uiSans
    font.pixelSize: quickStorageRoot.root.fontPx(10)
    elide: Text.ElideRight
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Hero: root disk ring + used / total, status chip, Refresh.
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(root.launcherGeom.rowHTall * 3.2)
      radius: Style.menuPanelRadius
      color: Style.m3container
      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 18
        Menu.MenuHudDial {
          Layout.fillHeight: true
          Layout.preferredWidth: height
          value: quickStorageRoot.rootMount ? quickStorageRoot.rootMount.pct : 0
          accent: quickStorageRoot.mountColor(quickStorageRoot.rootMount ? quickStorageRoot.rootMount.pct : 0)
          label: "Used"
          icon: "󰋊"
          fontFamily: root.uiFont
          labelFamily: root.uiSans
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text {
            text: "Storage"
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(17); font.weight: Font.DemiBold
          }
          Text {
            Layout.fillWidth: true
            text: quickStorageRoot.rootMount
              ? root.prettyBytes(quickStorageRoot.rootMount.used) + " / " + root.prettyBytes(quickStorageRoot.rootMount.total)
                + " · " + (quickStorageRoot.rootMount.mount === "/" ? "root" : quickStorageRoot.rootMount.mount)
              : "Reading mount points…"
            color: Style.m3secondary; font.family: root.uiSans; font.pixelSize: root.fontPx(13); font.weight: Font.Medium; elide: Text.ElideRight
          }
          Secondary {
            Layout.fillWidth: true
            text: quickStorageRoot.rootMount ? root.prettyBytes(quickStorageRoot.rootMount.avail) + " free" : ""
            font.pixelSize: root.fontPx(11)
          }
          Text {
            visible: root.storageError !== ""
            Layout.fillWidth: true
            text: root.storageError
            color: Style.red; font.family: root.uiSans; font.pixelSize: root.fontPx(10); elide: Text.ElideRight
          }
          Item { Layout.fillHeight: true }
          RowLayout {
            Layout.topMargin: 6
            spacing: 8
            Pill { icon: "󰑐"; label: "Refresh"; bg: Style.m3primaryContainer; fg: Style.m3primary; onClicked: root.scanStorage(true) }
            Chip {
              icon: root.storageStatus === "scanning" ? "󰔟" : "󰥔"
              label: root.storageStatus === "scanning" ? "scanning…" : (root.storageUpdated ? "updated " + root.storageUpdated : "idle")
              bg: Style.m3tertiaryContainer
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "R " + QuickModels.formatRate(quickStorageRoot.diskRead)
                + "   W " + QuickModels.formatRate(quickStorageRoot.diskWrite)
              color: Style.m3onSurfaceVariant
              font.family: root.uiSans; font.pixelSize: root.fontPx(12); font.weight: Font.Medium
            }
          }
        }
      }
    }

    // Filesystems (left) + home folders (right).
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 12

      Rectangle {
        Layout.preferredWidth: Math.round(quickStorageRoot.width * 0.4)
        Layout.fillHeight: true
        radius: Style.menuRadiusLg
        color: Style.m3container
        clip: true
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰋊"; color: Style.m3secondary; font.family: root.uiFont; font.pixelSize: root.fontPx(14) }
            CardTitle { text: "Filesystems"; Layout.fillWidth: true }
            // The hero already shows "/" — count only the rows listed here.
            Secondary {
              text: quickStorageRoot.otherMounts.length + (quickStorageRoot.otherMounts.length === 1 ? " mount" : " mounts")
              font.pixelSize: root.fontPx(9)
            }
          }
          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: mountCol.implicitHeight
            ScrollBar.vertical: Menu.MenuScrollBar { id: mountScroll }
            Column {
              id: mountCol
              // Gutter so the scrollbar never sits on the size column.
              width: parent.width - (mountScroll.overflow ? mountScroll.implicitWidth + 4 : 0)
              spacing: 2
              Secondary {
                visible: (root.storageMounts || []).length === 0
                text: root.storageStatus === "scanning" ? "Reading mount points…" : "No mounts"
                leftPadding: 8; topPadding: 6
              }
              Repeater {
                model: quickStorageRoot.otherMounts
                delegate: Rectangle {
                  id: mountRowRoot
                  required property var modelData
                  width: mountCol.width
                  height: mountRow.implicitHeight + 16
                  radius: Style.menuRadiusMd
                  color: mma.containsMouse ? Style.m3stateHover : "transparent"
                  Behavior on color { ColorAnimation { duration: 120 } }
                  ColumnLayout {
                    id: mountRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 5
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      Text {
                        text: mountRowRoot.modelData.highlight ? "󰉋" : "󰋊"
                        color: Style.m3onSurfaceVariant; font.family: root.uiFont; font.pixelSize: root.fontPx(12)
                      }
                      Text {
                        Layout.fillWidth: true
                        text: mountRowRoot.modelData.mount
                        color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                        font.weight: Font.Medium; elide: Text.ElideMiddle
                      }
                      Text {
                        text: mountRowRoot.modelData.pct + "%"
                        color: quickStorageRoot.mountColor(mountRowRoot.modelData.pct)
                        font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.DemiBold
                      }
                    }
                    Secondary {
                      Layout.fillWidth: true
                      text: root.prettyBytes(mountRowRoot.modelData.used) + " / " + root.prettyBytes(mountRowRoot.modelData.total)
                        + " · " + root.prettyBytes(mountRowRoot.modelData.avail) + " free"
                      font.pixelSize: root.fontPx(9)
                    }
                    UsageBar {
                      Layout.fillWidth: true
                      frac: mountRowRoot.modelData.pct / 100
                      accent: quickStorageRoot.mountColor(mountRowRoot.modelData.pct)
                    }
                  }
                  MouseArea {
                    id: mma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached([root.binDir + "/asahi-launch", "xdg-open", mountRowRoot.modelData.mount])
                  }
                }
              }
            }
          }

          // Connected external disks, only while one is plugged in.
          ColumnLayout {
            visible: quickStorageRoot.usbDisks.length > 0
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
              Layout.fillWidth: true
              spacing: 8
              Text { text: "󰕓"; color: Style.m3secondary; font.family: root.uiFont; font.pixelSize: root.fontPx(14) }
              CardTitle { text: "Devices"; Layout.fillWidth: true }
              Secondary {
                text: quickStorageRoot.usbDisks.length + (quickStorageRoot.usbDisks.length === 1 ? " disk" : " disks")
                font.pixelSize: root.fontPx(9)
              }
            }
            Repeater {
              model: quickStorageRoot.usbDisks
              delegate: Rectangle {
                id: usbRowRoot
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: usbCol.implicitHeight + 12
                radius: Style.menuRadiusMd
                color: Style.m3containerHigh
                ColumnLayout {
                  id: usbCol
                  anchors.fill: parent
                  anchors.margins: 6
                  anchors.leftMargin: 8
                  spacing: 3
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                      Layout.fillWidth: true
                      text: usbRowRoot.modelData.name || usbRowRoot.modelData.path
                      color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                      font.weight: Font.Medium; elide: Text.ElideRight
                    }
                    Secondary {
                      text: [root.prettyBytes(usbRowRoot.modelData.size), quickStorageRoot.usbSpeed(usbRowRoot.modelData.speed)]
                        .filter(function(x) { return x }).join(" · ")
                      font.pixelSize: root.fontPx(9)
                    }
                    Rectangle {
                      implicitWidth: 24; implicitHeight: 24; radius: 12
                      color: ejectMa.containsMouse ? Style.m3stateHover : "transparent"
                      Text {
                        anchors.centerIn: parent
                        text: "󰇪"; color: Style.m3onSurfaceVariant
                        font.family: root.uiFont; font.pixelSize: root.fontPx(12)
                      }
                      MouseArea {
                        id: ejectMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: quickStorageRoot.usbAction(["eject", usbRowRoot.modelData.path])
                      }
                    }
                  }
                  // One line per partition: click mounts, or opens once mounted.
                  Repeater {
                    model: usbRowRoot.modelData.partitions
                    delegate: Item {
                      id: partRoot
                      required property var modelData
                      Layout.fillWidth: true
                      implicitHeight: partCol.implicitHeight
                      ColumnLayout {
                        id: partCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 2
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 6
                          Secondary {
                            Layout.fillWidth: true
                            text: (partRoot.modelData.label || partRoot.modelData.path.replace("/dev/", "")) + " · " + partRoot.modelData.fstype
                            color: partMa.containsMouse ? Style.m3onSurface : Style.m3onSurfaceVariant
                            font.pixelSize: root.fontPx(9)
                          }
                          Secondary {
                            text: partRoot.modelData.mount
                              ? root.prettyBytes(partRoot.modelData.used) + " / " + root.prettyBytes(partRoot.modelData.size)
                              : "mount"
                            color: partRoot.modelData.mount ? Style.m3onSurfaceVariant : Style.m3primary
                            font.pixelSize: root.fontPx(9)
                          }
                        }
                        UsageBar {
                          visible: !!partRoot.modelData.mount
                          Layout.fillWidth: true
                          implicitHeight: 3
                          frac: partRoot.modelData.size > 0 ? partRoot.modelData.used / partRoot.modelData.size : 0
                          accent: quickStorageRoot.mountColor(partRoot.modelData.size > 0 ? 100 * partRoot.modelData.used / partRoot.modelData.size : 0)
                        }
                      }
                      MouseArea {
                        id: partMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: partRoot.modelData.mount
                          ? Quickshell.execDetached([root.binDir + "/asahi-launch", "xdg-open", partRoot.modelData.mount])
                          : quickStorageRoot.usbAction(["mount", partRoot.modelData.path])
                      }
                    }
                  }
                }
              }
            }
            Text {
              visible: quickStorageRoot.usbError !== ""
              Layout.fillWidth: true
              text: quickStorageRoot.usbError
              color: Style.red; font.family: root.uiSans; font.pixelSize: root.fontPx(9); elide: Text.ElideRight
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.menuRadiusLg
        color: Style.m3container
        clip: true
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰋜"; color: Style.m3tertiary; font.family: root.uiFont; font.pixelSize: root.fontPx(14) }
            CardTitle { text: "Home"; Layout.fillWidth: true }
            Chip {
              icon: "󰉋"
              label: root.prettyBytes(root.storageHomeTotal)
              bg: Style.m3tertiaryContainer
              implicitHeight: 24
            }
          }
          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: dirCol.implicitHeight
            ScrollBar.vertical: Menu.MenuScrollBar { id: dirScroll }
            Column {
              id: dirCol
              // Gutter so the scrollbar never sits on the size column.
              width: parent.width - (dirScroll.overflow ? dirScroll.implicitWidth + 4 : 0)
              spacing: 2
              Secondary {
                visible: (root.storageHomeDirs || []).length === 0
                text: root.storageStatus === "scanning" ? "Sizing folders…" : "No folders"
                leftPadding: 8; topPadding: 6
              }
              Repeater {
                model: root.storageHomeDirs || []
                delegate: Rectangle {
                  id: dirRowRoot
                  required property var modelData
                  width: dirCol.width
                  height: 44
                  radius: Style.menuRadiusMd
                  color: dma.containsMouse ? Style.m3stateHover : "transparent"
                  Behavior on color { ColorAnimation { duration: 120 } }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 10
                    spacing: 10
                    Text {
                      Layout.preferredWidth: 22
                      text: dirRowRoot.modelData.name.indexOf("~.") === 0 ? "󰉖" : "󰉋"
                      color: Style.m3tertiary; font.family: root.uiFont; font.pixelSize: root.fontPx(14)
                      horizontalAlignment: Text.AlignHCenter
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 4
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                          Layout.fillWidth: true
                          text: dirRowRoot.modelData.name
                          color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                          font.weight: Font.Medium; elide: Text.ElideMiddle
                        }
                        Secondary { text: dirRowRoot.modelData.pct + "%"; font.pixelSize: root.fontPx(9) }
                        Text {
                          text: root.prettyBytes(dirRowRoot.modelData.bytes)
                          color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.DemiBold
                        }
                      }
                      UsageBar { Layout.fillWidth: true; implicitHeight: 4; radius: 2; frac: dirRowRoot.modelData.bar || 0; accent: Style.m3tertiary }
                    }
                  }
                  MouseArea {
                    id: dma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached([root.binDir + "/asahi-launch", "xdg-open", dirRowRoot.modelData.path])
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
