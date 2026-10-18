import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels

// Storage pane: root volume hero, then devices / filesystems / home folders as full-width rows in one scroll.
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
  // "fedora · btrfs zstd:1"
  function fsDetails(m) { return [m.label, m.fstype + (m.compress ? " " + m.compress : "")].filter(function(x) { return x }).join(" · ") }

  // Hero: the filesystem holding "/" (on btrfs also /home), the rest go to the list.
  readonly property var rootMount: root.storageMounts.find(m => m.mounts.indexOf("/") >= 0) || null
  readonly property var otherMounts: root.storageMounts.filter(m => m !== quickStorageRoot.rootMount)
  // du counts uncompressed bytes: on a compressed volume Home can exceed the volume's used space.
  readonly property bool homeCompressed: {
    const m = root.storageMounts.find(fs => fs.mounts.indexOf(root.homeDir) >= 0 || fs.mounts.indexOf("/home") >= 0) || rootMount
    return !!(m && m.compress)
  }

  Component.onCompleted: { Qt.callLater(root.scanStorage); listUsb() }

  // External disks (USB / hotplug): listed on open, then on udev block events while the launcher shows.
  property var usbDisks: []
  property string usbError: ""
  property string usbBusy: ""  // running action as "<verb> <device>" (a whole-disk filesystem shares the disk's path)
  property bool devOpen: true
  property bool fsOpen: true
  property bool homeOpen: true
  function listUsb() { if (!usbListProc.running) usbListProc.running = true }
  function usbAction(args) {
    if (usbActionProc.running) return
    quickStorageRoot.usbError = ""
    quickStorageRoot.usbBusy = args.join(" ")
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
    onExited: { quickStorageRoot.usbBusy = ""; quickStorageRoot.listUsb() }
  }

  // ---- M3 building blocks (caelestia look) ----
  component Pill: Menu.MenuPill { fontScale: quickStorageRoot.root.uiFontScale }
  component Chip: Menu.MenuChip { fontScale: quickStorageRoot.root.uiFontScale }

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
    font.pixelSize: quickStorageRoot.root.fontPx(9)
    elide: Text.ElideRight
  }
  component Glyph: Text {
    color: Style.m3onSurfaceVariant
    font.family: quickStorageRoot.root.uiFont
    font.pixelSize: quickStorageRoot.root.fontPx(12)
    horizontalAlignment: Text.AlignHCenter
    Layout.preferredWidth: quickStorageRoot.root.fontPx(16)
  }
  // Fixed-width, right-aligned table cell (bars and numbers line up row to row).
  component Cell: Secondary {
    property real w: 60
    Layout.preferredWidth: quickStorageRoot.root.fontPx(w)
    horizontalAlignment: Text.AlignRight
  }
  // Click toggles the section below it.
  component SectionHeader: Rectangle {
    id: sectionHead
    property string icon: ""
    property color tint: Style.m3secondary
    property string title: ""
    property string count: ""
    property bool open: true
    signal toggled()
    Layout.fillWidth: true
    implicitHeight: quickStorageRoot.root.fontPx(26)
    radius: Style.menuRadiusMd
    color: headMa.containsMouse ? Style.m3stateHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
    MouseArea { id: headMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sectionHead.toggled() }
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 6; anchors.rightMargin: 8
      spacing: 8
      Glyph { text: sectionHead.icon; color: sectionHead.tint; font.pixelSize: quickStorageRoot.root.fontPx(14) }
      CardTitle { text: sectionHead.title; Layout.fillWidth: true }
      Secondary { text: sectionHead.count }
      Glyph { text: sectionHead.open ? "󰅀" : "󰅂"; font.pixelSize: quickStorageRoot.root.fontPx(11) }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Hero: root volume ring, used / total / free, volume details, Refresh + I/O.
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(root.launcherGeom.rowHTall * 2)
      radius: Style.menuPanelRadius
      color: Style.m3container
      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.leftMargin: 16
        spacing: 16
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
          Layout.alignment: Qt.AlignVCenter
          spacing: 2
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
              Layout.fillWidth: true
              text: "Storage"
              color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(15); font.weight: Font.DemiBold
            }
            // Mounted read-only (btrfs / vfat remount ro after errors).
            Text {
              visible: !!(quickStorageRoot.rootMount && quickStorageRoot.rootMount.ro)
              text: "read-only"
              color: Style.red; font.family: root.uiSans; font.pixelSize: root.fontPx(10); font.weight: Font.DemiBold
            }
            Pill { icon: "󰑐"; label: "Refresh"; bg: Style.m3primaryContainer; fg: Style.m3primary; onClicked: root.scanStorage(true) }
            Chip {
              icon: root.storageStatus === "scanning" ? "󰔟" : "󰥔"
              label: root.storageStatus === "scanning" ? "scanning…" : (root.storageUpdated ? "updated " + root.storageUpdated : "idle")
              bg: Style.m3tertiaryContainer
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
              Layout.fillWidth: true
              text: quickStorageRoot.rootMount
                ? root.prettyBytes(quickStorageRoot.rootMount.used) + " / " + root.prettyBytes(quickStorageRoot.rootMount.total)
                  + " · " + root.prettyBytes(quickStorageRoot.rootMount.avail) + " free"
                : "Reading mount points…"
              color: Style.m3secondary; font.family: root.uiSans; font.pixelSize: root.fontPx(13); font.weight: Font.Medium; elide: Text.ElideRight
            }
            Text {
              text: "R " + QuickModels.formatRate(quickStorageRoot.diskRead) + "   W " + QuickModels.formatRate(quickStorageRoot.diskWrite)
              color: Style.m3onSurfaceVariant
              font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium
            }
          }
          // "/ + /home · fedora · btrfs zstd:1 · APPLE SSD AP1024Z", or the scan error.
          Secondary {
            Layout.fillWidth: true
            text: root.storageError || (quickStorageRoot.rootMount
              ? [quickStorageRoot.rootMount.mounts.join(" + "), quickStorageRoot.fsDetails(quickStorageRoot.rootMount),
                quickStorageRoot.rootMount.model].filter(function(x) { return x }).join(" · ")
              : "")
            textFormat: Text.PlainText
            color: root.storageError ? Style.red : Style.m3onSurfaceVariant
            font.pixelSize: root.fontPx(10)
          }
        }
      }
    }

    // Devices, filesystems, home folders: one line per item, one scroll.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.menuRadiusLg
      color: Style.m3container
      clip: true
      Flickable {
        id: listFlick
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: listCol.implicitHeight
        ScrollBar.vertical: Menu.MenuScrollBar { id: listScroll }
        ColumnLayout {
          id: listCol
          // Gutter so the scrollbar never sits on the size column.
          width: listFlick.width - (listScroll.overflow ? listScroll.implicitWidth + 4 : 0)
          spacing: 2

          // ---- Devices: connected external disks, only while one is plugged in ----
          SectionHeader {
            visible: quickStorageRoot.usbDisks.length > 0
            icon: "󰕓"
            title: "Devices"
            count: quickStorageRoot.usbDisks.length + (quickStorageRoot.usbDisks.length === 1 ? " disk" : " disks")
            open: quickStorageRoot.devOpen
            onToggled: quickStorageRoot.devOpen = !quickStorageRoot.devOpen
          }
          Repeater {
            model: quickStorageRoot.usbDisks
            delegate: Rectangle {
              id: usbRowRoot
              required property var modelData
              visible: quickStorageRoot.devOpen
              Layout.fillWidth: true
              Layout.bottomMargin: 4
              implicitHeight: usbCol.implicitHeight + 16
              radius: Style.menuRadiusMd
              color: Style.m3containerHigh
              ColumnLayout {
                id: usbCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                anchors.leftMargin: 12
                spacing: 6
                // Name, node · size · link speed, Eject.
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10
                  Text {
                    Layout.maximumWidth: usbCol.width * 0.5
                    text: usbRowRoot.modelData.name || usbRowRoot.modelData.path
                    textFormat: Text.PlainText
                    color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                    font.weight: Font.Medium; elide: Text.ElideRight
                  }
                  Secondary {
                    Layout.fillWidth: true
                    // Size 0 = card reader slot without a card.
                    text: [usbRowRoot.modelData.path.replace("/dev/", ""),
                      usbRowRoot.modelData.size > 0 ? root.prettyBytes(usbRowRoot.modelData.size) : "no media",
                      quickStorageRoot.usbSpeed(usbRowRoot.modelData.speed)].filter(function(x) { return x }).join(" · ")
                  }
                  Pill {
                    icon: "󰇪"
                    label: quickStorageRoot.usbBusy === "eject " + usbRowRoot.modelData.path ? "Ejecting…" : "Eject"
                    bg: Style.m3container
                    onClicked: quickStorageRoot.usbAction(["eject", usbRowRoot.modelData.path])
                  }
                }
                // One line per partition: Mount, or mount point + usage + Unmount (click opens).
                Repeater {
                  model: usbRowRoot.modelData.partitions
                  delegate: Rectangle {
                    id: partRoot
                    required property var modelData
                    readonly property bool mounted: !!modelData.mount
                    readonly property bool busy: quickStorageRoot.usbBusy === (mounted ? "unmount " : "mount ") + modelData.path
                    Layout.fillWidth: true
                    implicitHeight: partCol.implicitHeight + 12
                    radius: Style.menuRadiusMd
                    color: partMa.containsMouse ? Style.m3stateHover : Style.m3container
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                      id: partMa
                      anchors.fill: parent
                      enabled: partRoot.mounted
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: Quickshell.execDetached([root.binDir + "/asahi-launch", "xdg-open", partRoot.modelData.mount])
                    }
                    ColumnLayout {
                      id: partCol
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.leftMargin: 10
                      anchors.rightMargin: 6
                      spacing: 4
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Glyph { text: partRoot.mounted ? "󰉋" : "󰋊"; font.pixelSize: root.fontPx(11) }
                        Text {
                          Layout.preferredWidth: root.fontPx(110)
                          // Node only for real partitions (a whole-disk filesystem repeats the disk line).
                          text: [partRoot.modelData.label,
                            partRoot.modelData.path !== usbRowRoot.modelData.path ? partRoot.modelData.path.replace("/dev/", "") : "",
                            partRoot.modelData.fstype].filter(function(x) { return x }).join(" · ")
                          textFormat: Text.PlainText
                          color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
                          elide: Text.ElideRight
                        }
                        Secondary {
                          Layout.fillWidth: true
                          text: partRoot.modelData.mount
                          textFormat: Text.PlainText
                          elide: Text.ElideLeft  // keep the mount point's own name
                        }
                        Cell {
                          visible: partRoot.mounted
                          w: 100
                          text: root.prettyBytes(partRoot.modelData.used) + " / " + root.prettyBytes(partRoot.modelData.size)
                        }
                        Cell {
                          visible: partRoot.mounted
                          w: 70
                          text: root.prettyBytes(partRoot.modelData.avail) + " free"
                        }
                        Pill {
                          icon: partRoot.mounted ? "󰅖" : "󰋊"
                          label: partRoot.mounted ? (partRoot.busy ? "Unmounting…" : "Unmount") : (partRoot.busy ? "Mounting…" : "Mount")
                          bg: partRoot.mounted ? Style.m3containerHigh : Style.m3primaryContainer
                          fg: partRoot.mounted ? Style.m3onSurface : Style.m3primary
                          onClicked: quickStorageRoot.usbAction([partRoot.mounted ? "unmount" : "mount", partRoot.modelData.path])
                        }
                      }
                      UsageBar {
                        visible: partRoot.mounted
                        Layout.fillWidth: true
                        implicitHeight: 3
                        frac: partRoot.modelData.size > 0 ? partRoot.modelData.used / partRoot.modelData.size : 0
                        accent: quickStorageRoot.mountColor(partRoot.modelData.size > 0 ? 100 * partRoot.modelData.used / partRoot.modelData.size : 0)
                      }
                    }
                  }
                }
              }
            }
          }
          Text {
            visible: quickStorageRoot.usbError !== ""
            Layout.fillWidth: true
            Layout.leftMargin: 6
            text: quickStorageRoot.usbError
            textFormat: Text.PlainText
            color: Style.red; font.family: root.uiSans; font.pixelSize: root.fontPx(9)
            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
          }

          // ---- Filesystems: everything but the hero's volume ----
          SectionHeader {
            Layout.topMargin: quickStorageRoot.usbDisks.length > 0 ? 8 : 0
            icon: "󰋊"
            title: "Filesystems"
            count: quickStorageRoot.otherMounts.length + (quickStorageRoot.otherMounts.length === 1 ? " mount" : " mounts")
            open: quickStorageRoot.fsOpen
            onToggled: quickStorageRoot.fsOpen = !quickStorageRoot.fsOpen
          }
          Secondary {
            visible: quickStorageRoot.fsOpen && quickStorageRoot.otherMounts.length === 0
            Layout.fillWidth: true
            Layout.leftMargin: 8
            text: root.storageStatus === "scanning" ? "Reading mount points…" : "No other mounts"
          }
          Repeater {
            model: quickStorageRoot.otherMounts
            delegate: Rectangle {
              id: mountRowRoot
              required property var modelData
              visible: quickStorageRoot.fsOpen
              Layout.fillWidth: true
              implicitHeight: root.fontPx(28)
              radius: Style.menuRadiusMd
              color: mma.containsMouse ? Style.m3stateHover : "transparent"
              Behavior on color { ColorAnimation { duration: 120 } }
              MouseArea {
                id: mma
                anchors.fill: parent
                // root-only /boot/efi: the file manager could not list it (a cache from before the flag has none)
                enabled: mountRowRoot.modelData.readable !== false
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached([root.binDir + "/asahi-launch", "xdg-open", mountRowRoot.modelData.mounts[0]])
              }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6; anchors.rightMargin: 8
                spacing: 10
                Glyph { text: "󰋊" }
                Text {
                  Layout.preferredWidth: root.fontPx(80)
                  text: mountRowRoot.modelData.mounts.join(" + ")
                  textFormat: Text.PlainText
                  color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                  font.weight: Font.Medium; elide: Text.ElideMiddle
                }
                Secondary {
                  Layout.fillWidth: true
                  text: quickStorageRoot.fsDetails(mountRowRoot.modelData)
                  textFormat: Text.PlainText
                }
                UsageBar {
                  Layout.preferredWidth: root.fontPx(120)
                  frac: mountRowRoot.modelData.pct / 100
                  accent: quickStorageRoot.mountColor(mountRowRoot.modelData.pct)
                }
                Cell { w: 100; text: root.prettyBytes(mountRowRoot.modelData.used) + " / " + root.prettyBytes(mountRowRoot.modelData.total) }
                // Read-only (remounted after errors): free space is moot, flag it there.
                Cell {
                  w: 70
                  text: mountRowRoot.modelData.ro ? "read-only" : root.prettyBytes(mountRowRoot.modelData.avail) + " free"
                  color: mountRowRoot.modelData.ro ? Style.red : Style.m3onSurfaceVariant
                  font.weight: mountRowRoot.modelData.ro ? Font.DemiBold : Font.Normal
                }
                Cell {
                  w: 32
                  text: mountRowRoot.modelData.pct + "%"
                  color: quickStorageRoot.mountColor(mountRowRoot.modelData.pct)
                  font.pixelSize: root.fontPx(11); font.weight: Font.DemiBold
                }
              }
            }
          }

          // ---- Home: depth-1 folders, largest first ----
          SectionHeader {
            Layout.topMargin: 8
            icon: "󰋜"
            tint: Style.m3tertiary
            title: "Home"
            count: root.storageHomeTotal > 0 ? root.prettyBytes(root.storageHomeTotal) + (quickStorageRoot.homeCompressed ? " uncompressed" : "") : ""
            open: quickStorageRoot.homeOpen
            onToggled: quickStorageRoot.homeOpen = !quickStorageRoot.homeOpen
          }
          Secondary {
            visible: quickStorageRoot.homeOpen && (root.storageHomeDirs || []).length === 0
            Layout.fillWidth: true
            Layout.leftMargin: 8
            text: root.storageStatus === "scanning" ? "Sizing folders…" : "No folders"
          }
          Repeater {
            model: root.storageHomeDirs || []
            delegate: Rectangle {
              id: dirRowRoot
              required property var modelData
              visible: quickStorageRoot.homeOpen
              Layout.fillWidth: true
              implicitHeight: root.fontPx(26)
              radius: Style.menuRadiusMd
              color: dma.containsMouse ? Style.m3stateHover : "transparent"
              Behavior on color { ColorAnimation { duration: 120 } }
              MouseArea {
                id: dma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached([root.binDir + "/asahi-launch", "xdg-open", dirRowRoot.modelData.path])
              }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6; anchors.rightMargin: 8
                spacing: 10
                Glyph {
                  text: dirRowRoot.modelData.name.indexOf("~/.") === 0 ? "󰉖" : "󰉋"
                  color: Style.m3tertiary
                }
                Text {
                  Layout.preferredWidth: root.fontPx(130)
                  text: dirRowRoot.modelData.name
                  textFormat: Text.PlainText
                  color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                  font.weight: Font.Medium; elide: Text.ElideMiddle
                }
                UsageBar { Layout.fillWidth: true; frac: dirRowRoot.modelData.bar || 0; accent: Style.m3tertiary }
                Cell { w: 32; text: dirRowRoot.modelData.pct + "%" }
                Cell {
                  w: 62
                  text: root.prettyBytes(dirRowRoot.modelData.bytes)
                  color: Style.m3onSurface; font.pixelSize: root.fontPx(11); font.weight: Font.DemiBold
                }
              }
            }
          }
        }
      }
    }
  }
}
