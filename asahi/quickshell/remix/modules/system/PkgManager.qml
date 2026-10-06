import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../menu" as Menu
import "../launcher/launcher_layout.js" as LauncherGeom
import "../../"

Scope {
  id: root

  property bool open: false
  property var pkgScreen: null
  property int tab: 0 // 0 search 1 installed 2 updates
  property string query: ""
  property var packages: []
  property var selected: ({})
  property bool loading: false
  property string status: ""
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  // Launcher geometry and type scale for the screen, so this card matches the launcher.
  readonly property var geom: LauncherGeom.launcherLayout({ screenW: pkgPanel.width || 1920, screenH: pkgPanel.height || 1080,
    tileCount: 11, sideActive: true, quickMode: true, headerVisible: false, hubMode: false })
  function px(n) { return Math.round(n * root.geom.fontScale) }
  readonly property var selectedNames: {
    const out = []
    for (const k in root.selected) out.push(k)
    return out
  }

  function focusedScreen() {
    const mon = Hyprland.focusedMonitor
    return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
  }

  function toggleSelect(pkg) {
    const next = Object.assign({}, root.selected)
    if (next[pkg.name]) delete next[pkg.name]
    else next[pkg.name] = pkg
    root.selected = next
  }

  function isSelected(name) {
    return !!root.selected[name]
  }

  function clearQueue() {
    root.selected = ({})
  }

  function runQuery() {
    root.loading = true
    root.status = ""
    if (root.tab === 0) {
      pkgProc.command = ["bash", root.binDir + "/asahi-pkg", "search", root.query]
    } else if (root.tab === 1) {
      pkgProc.command = ["bash", root.binDir + "/asahi-pkg", "installed", root.query]
    } else {
      pkgProc.command = ["bash", root.binDir + "/asahi-pkg", "updates"]
    }
    pkgProc.running = true
  }

  function applyQueue(kind) {
    const names = root.selectedNames
    if (kind !== "upgrade-all" && names.length === 0) {
      root.status = "Select packages first"
      return
    }
    let cmd = ["bash", root.binDir + "/asahi-pkg"]
    if (kind === "install") cmd = cmd.concat(["tui-install"]).concat(names)
    else if (kind === "remove") cmd = cmd.concat(["tui-remove"]).concat(names)
    else if (kind === "upgrade-all") cmd = cmd.concat(["tui-upgrade"])
    else cmd = cmd.concat(["tui-upgrade"]).concat(names)
    Quickshell.execDetached(cmd)
    root.open = false
  }

  // The bar's update chip calls this in-process (shell.qml); the keybind uses IPC.
  function toggle() {
    if (!root.open) root.pkgScreen = root.focusedScreen()
    root.open = !root.open
    if (root.open) {
      root.tab = 0
      root.query = ""
      root.packages = []
      root.status = "Type a name and search"
      Qt.callLater(function () { searchField.forceActiveFocus() })
    }
  }

  IpcHandler {
    target: "pkgman"
    function toggle(): void { root.toggle() }
  }

  Process {
    id: pkgProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loading = false
        try {
          const data = JSON.parse(text || "{}")
          root.packages = data.packages || []
          if (data.error === "empty-query") root.status = "Type a package name"
          else if (root.packages.length === 0) root.status = "No packages"
          else root.status = root.packages.length + " packages"
        } catch (e) {
          root.packages = []
          root.status = "Parse failed"
        }
      }
    }
    onExited: function () { root.loading = false }
  }

  Timer {
    id: searchDebounce
    interval: 280
    onTriggered: {
      if (root.tab === 0 && root.query.trim().length >= 2) root.runQuery()
    }
  }

  // Tonal pill button (recorder / launcher panes).
  component Pill: Rectangle {
    id: pill
    property string icon: ""
    property string label: ""
    property color bg: Style.m3containerHigh
    property color fg: Style.m3onSurface
    signal clicked()
    implicitWidth: pillRow.implicitWidth + root.px(22)
    implicitHeight: root.px(30)
    radius: height / 2
    color: pillMa.containsMouse ? Qt.lighter(bg, 1.12) : bg
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: root.px(6)
      Text { visible: pill.icon !== ""; text: pill.icon; color: pill.fg; font.family: Style.menuMono; font.pixelSize: root.px(13); anchors.verticalCenter: parent.verticalCenter }
      Text { text: pill.label; color: pill.fg; font.family: Style.menuSans; font.pixelSize: root.px(11); font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
  }

  PanelWindow {
    id: pkgPanel
    visible: root.open
    focusable: true
    color: "transparent"
    screen: root.pkgScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-pkgman"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    FocusScope {
      anchors.fill: parent
      focus: root.open
      Keys.onEscapePressed: root.open = false

      Menu.MenuBackdrop { reveal: root.open ? 1 : 0 }

      MouseArea {
        anchors.fill: parent
        onClicked: root.open = false
      }

    // Same footprint as the launcher card on this screen.
    Menu.MenuCard {
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.geom.cardY
      width: root.geom.cardWidth
      height: root.geom.cardHeight
      cardMargin: root.geom.cardMargin

      ColumnLayout {
        anchors.fill: parent
        spacing: root.px(10)

        // Header: glyph tile, title + status, tabs.
        RowLayout {
          Layout.fillWidth: true
          spacing: root.px(12)
          Rectangle {
            width: root.px(40); height: width; radius: Style.menuRadiusMd
            color: Style.m3primaryContainer
            Text { anchors.centerIn: parent; text: "󰏖"; color: Style.m3primary; font.family: Style.menuMono; font.pixelSize: root.px(20) }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { text: "Packages"; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: root.px(16); font.weight: Font.DemiBold }
            Text {
              Layout.fillWidth: true
              text: root.loading ? (root.tab === 2 ? "Checking for updates…" : "Searching…") : root.status
              color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: root.px(10); elide: Text.ElideRight
            }
          }
          // Segmented tabs.
          Rectangle {
            implicitWidth: tabRow.implicitWidth + root.px(8)
            implicitHeight: root.px(36)
            radius: height / 2
            color: Style.m3container
            Row {
              id: tabRow
              anchors.centerIn: parent
              spacing: root.px(2)
              Repeater {
                model: [
                  { id: 0, label: "Search", icon: "󰍉" },
                  { id: 1, label: "Installed", icon: "󰏗" },
                  { id: 2, label: "Updates", icon: "󰚰" }
                ]
                Rectangle {
                  required property var modelData
                  readonly property bool on: root.tab === modelData.id
                  implicitWidth: tabInner.implicitWidth + root.px(22)
                  implicitHeight: root.px(28)
                  radius: height / 2
                  color: on ? Style.m3primary : (tabMa.containsMouse ? Style.m3stateHover : "transparent")
                  Behavior on color { ColorAnimation { duration: 120 } }
                  Row {
                    id: tabInner
                    anchors.centerIn: parent
                    spacing: root.px(5)
                    Text { text: modelData.icon; color: on ? Style.m3onPrimary : Style.m3onSurfaceVariant; font.family: Style.menuMono; font.pixelSize: root.px(12); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: modelData.label; color: on ? Style.m3onPrimary : Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: root.px(11); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                  }
                  MouseArea {
                    id: tabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.tab = modelData.id
                      if (modelData.id === 2 || (modelData.id === 1 && root.query.trim() === "")) root.runQuery()
                      else if (modelData.id === 0 && root.query.trim().length >= 2) root.runQuery()
                    }
                  }
                }
              }
            }
          }
        }

        // Search field (launcher search pill).
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: root.px(40)
          radius: height / 2
          color: Style.m3container
          border.width: searchField.activeFocus ? 1 : 0
          border.color: Style.menuSelBorder
          visible: root.tab !== 2
          Text {
            id: searchGlyph
            anchors.left: parent.left; anchors.leftMargin: root.px(14)
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"; color: Style.m3onSurfaceVariant; font.family: Style.menuMono; font.pixelSize: root.px(14)
          }
          TextInput {
            id: searchField
            anchors.left: searchGlyph.right; anchors.leftMargin: root.px(10)
            anchors.right: parent.right; anchors.rightMargin: root.px(14)
            anchors.verticalCenter: parent.verticalCenter
            color: Style.m3onSurface
            font.family: Style.menuSans
            font.pixelSize: root.px(13)
            clip: true
            selectByMouse: true
            text: root.query
            onTextChanged: {
              root.query = text
              if (root.tab === 0) searchDebounce.restart()
            }
            Keys.onReturnPressed: root.runQuery()
            Keys.onEscapePressed: root.open = false
            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: !parent.text
              text: root.tab === 1 ? "Filter installed packages" : "Search dnf packages"
              color: Style.m3onSurfaceVariant
              font: parent.font
            }
          }
        }

        // Results, in one container card like the launcher lists.
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Style.menuRadiusLg
          color: Style.m3container
          clip: true

          ListView {
            id: pkgList
            anchors.fill: parent
            anchors.margins: root.px(6)
            clip: true
            spacing: root.px(2)
            boundsBehavior: Flickable.StopAtBounds
            model: root.packages
            ScrollBar.vertical: Menu.MenuScrollBar { id: pkgScroll }
            delegate: Rectangle {
              id: pkgRow
              required property var modelData
              readonly property bool sel: root.isSelected(modelData.name)
              width: pkgList.width - pkgScroll.width
              height: pkgText.implicitHeight + root.px(16)
              radius: Style.menuRadiusMd
              color: sel ? Style.menuSelFill : (rowMa.containsMouse ? Style.m3stateHover : "transparent")
              border.width: sel ? 1 : 0
              border.color: Style.menuSelBorder
              Behavior on color { ColorAnimation { duration: 120 } }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.px(8); anchors.rightMargin: root.px(12)
                spacing: root.px(10)
                Rectangle {
                  width: root.px(30); height: width; radius: Style.menuRadiusMd
                  color: pkgRow.sel ? Style.m3primary : Style.m3containerHigh
                  Text {
                    anchors.centerIn: parent
                    text: pkgRow.sel ? "󰄬" : "󰏗"
                    color: pkgRow.sel ? Style.m3onPrimary : Style.m3onSurfaceVariant
                    font.family: Style.menuMono; font.pixelSize: root.px(14)
                  }
                }
                ColumnLayout {
                  id: pkgText
                  Layout.fillWidth: true
                  spacing: 1
                  Text {
                    Layout.fillWidth: true
                    text: pkgRow.modelData.name
                    color: Style.m3onSurface
                    font.family: Style.menuSans; font.pixelSize: root.px(12); font.weight: Font.Medium
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: pkgRow.modelData.summary || pkgRow.modelData.repo || ""
                    color: Style.m3onSurfaceVariant
                    font.family: Style.menuSans; font.pixelSize: root.px(10)
                    elide: Text.ElideRight
                  }
                }
                // Version chip.
                Rectangle {
                  visible: !!pkgRow.modelData.version
                  implicitWidth: verLbl.implicitWidth + root.px(14); implicitHeight: root.px(22)
                  radius: height / 2
                  color: Style.m3secondaryContainer
                  Text {
                    id: verLbl
                    anchors.centerIn: parent
                    text: pkgRow.modelData.version || ""
                    color: Style.m3onSurface; font.family: Style.menuMono; font.pixelSize: root.px(9)
                  }
                }
              }
              MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleSelect(pkgRow.modelData)
              }
            }
          }

          Menu.MenuEmptyState {
            anchors.centerIn: parent
            visible: root.packages.length === 0
            fontScale: root.geom.fontScale
            glyph: root.loading ? "󰔟" : root.tab === 2 ? "󰚰" : root.tab === 1 ? "󰏗" : "󰏖"
            tint: Style.m3primary
            title: root.loading ? (root.tab === 2 ? "Checking for updates…" : "Searching…")
              : root.tab === 2 ? (root.status === "No packages" ? "Everything is up to date" : "Updates")
              : root.status === "No packages" ? "No matches"
              : root.tab === 1 ? "Installed packages" : "Find a package"
            detail: root.loading ? ""
              : root.tab === 2 ? ""
              : root.status === "No packages" ? "Try another name."
              : root.tab === 1 ? "Type to filter, then click rows to queue a removal."
              : "Type at least two letters. Click rows to queue them."
          }
        }

        // Footer: queue + actions. Install / remove run in Ghostty via sudo dnf.
        RowLayout {
          Layout.fillWidth: true
          spacing: root.px(8)
          Text {
            text: root.selectedNames.length ? root.selectedNames.length + " queued" : "Nothing queued"
            color: root.selectedNames.length ? Style.m3onSurface : Style.m3onSurfaceVariant
            font.family: Style.menuSans; font.pixelSize: root.px(11); font.weight: Font.Medium
          }
          Text {
            Layout.fillWidth: true
            text: "· runs in Ghostty via sudo dnf"
            color: Style.m3onSurfaceVariant
            font.family: Style.menuSans; font.pixelSize: root.px(10)
            elide: Text.ElideRight
          }
          Pill {
            visible: root.selectedNames.length > 0
            icon: "󰅖"; label: "Clear"
            onClicked: root.clearQueue()
          }
          Pill {
            visible: root.tab === 0
            icon: "󰇚"; label: "Install"
            bg: Style.m3primary; fg: Style.m3onPrimary
            onClicked: root.applyQueue("install")
          }
          Pill {
            visible: root.tab === 1
            icon: "󰆴"; label: "Remove"
            bg: Qt.alpha(Style.red, 0.18); fg: Style.red
            onClicked: root.applyQueue("remove")
          }
          Pill {
            visible: root.tab === 2
            icon: "󰚰"; label: "Upgrade selected"
            onClicked: root.applyQueue("upgrade")
          }
          Pill {
            visible: root.tab === 2
            icon: "󰚰"; label: "Upgrade all"
            bg: Style.m3primary; fg: Style.m3onPrimary
            onClicked: root.applyQueue("upgrade-all")
          }
        }
      }
    }
    }
  }
}
