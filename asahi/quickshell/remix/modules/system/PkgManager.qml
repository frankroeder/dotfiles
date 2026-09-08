import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../menu" as Menu
import "../../"

Scope {
  id: root

  property bool open: false
  property int tab: 0 // 0 search 1 installed 2 updates
  property string query: ""
  property var packages: []
  property var selected: ({})
  property bool loading: false
  property string status: ""
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
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

  IpcHandler {
    target: "pkgman"
    function toggle(): void {
      root.open = !root.open
      if (root.open) {
        root.tab = 0
        root.query = ""
        root.packages = []
        root.status = "Type a name and search"
        Qt.callLater(function () { searchField.forceActiveFocus() })
      }
    }
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

  PanelWindow {
    id: pkgPanel
    visible: root.open
    focusable: true
    color: "transparent"
    screen: root.focusedScreen()

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

    Menu.MenuCard {
      anchors.centerIn: parent
      width: Math.min(920, parent.width * 0.9)
      height: Math.min(680, parent.height * 0.82)
      cardMargin: 18

      ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Text {
            text: "󰏖"
            color: Style.menuSeal
            font.family: Style.fontFamily
            font.pixelSize: 20
          }
          Text {
            Layout.fillWidth: true
            text: "Packages"
            color: Style.menuInk
            font.family: Style.menuMono
            font.pixelSize: 16
            font.letterSpacing: 0.15
            font.weight: Font.Medium
          }
          Text {
            text: root.loading ? "searching…" : root.status
            color: Style.menuInkDeep
            font.family: Style.fontFamily
            font.pixelSize: 11
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: [
              { id: 0, label: "Search" },
              { id: 1, label: "Installed" },
              { id: 2, label: "Updates" }
            ]
            Rectangle {
              required property var modelData
              height: 28
              width: tabLbl.implicitWidth + 18
              radius: 8
              color: root.tab === modelData.id ? Style.menuRowSel : (tabMa.containsMouse ? Style.menuRowHi : Style.menuControlBg)
              border.width: 1
              border.color: root.tab === modelData.id ? Style.menuSeal : Style.menuSep
              Text {
                id: tabLbl
                anchors.centerIn: parent
                text: modelData.label
                color: Style.menuInk
                font.family: Style.fontFamily
                font.pixelSize: 12
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
          Item { Layout.fillWidth: true }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 36
          radius: 8
          color: Style.menuControlBg
          border.color: searchField.activeFocus ? Style.menuSeal : Style.menuSep
          border.width: 1
          visible: root.tab !== 2
          TextInput {
            id: searchField
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: Text.AlignVCenter
            color: Style.menuInk
            font.family: Style.fontFamily
            font.pixelSize: 13
            clip: true
            text: root.query
            onTextChanged: {
              root.query = text
              if (root.tab === 0) searchDebounce.restart()
            }
            Keys.onReturnPressed: root.runQuery()
            Keys.onEscapePressed: root.open = false
          }
        }

        ListView {
          id: pkgList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 4
          boundsBehavior: Flickable.StopAtBounds
          model: root.packages
          ScrollBar.vertical: Menu.MenuScrollBar {}
          delegate: Rectangle {
            required property var modelData
            width: pkgList.width
            height: 52
            radius: 8
            color: root.isSelected(modelData.name) ? Style.menuRowSel : (rowMa.containsMouse ? Style.menuRowHi : Style.menuControlBg)
            border.width: 1
            border.color: root.isSelected(modelData.name) ? Style.menuSeal : Style.menuSep
            RowLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: 10
              Text {
                text: root.isSelected(modelData.name) ? "󰄲" : "󰄱"
                color: root.isSelected(modelData.name) ? Style.menuSeal : Style.menuInkDeep
                font.pixelSize: 16
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                  Layout.fillWidth: true
                  text: modelData.name + (modelData.version ? "  " + modelData.version : "")
                  color: Style.menuInk
                  font.family: Style.fontFamily
                  font.pixelSize: 13
                  elide: Text.ElideRight
                }
                Text {
                  Layout.fillWidth: true
                  text: modelData.summary || modelData.repo || ""
                  color: Style.menuInkDeep
                  font.family: Style.fontFamily
                  font.pixelSize: 11
                  elide: Text.ElideRight
                }
              }
            }
            MouseArea {
              id: rowMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleSelect(modelData)
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: root.selectedNames.length ? root.selectedNames.length + " queued" : "Click to queue"
            color: Style.menuInkDeep
            font.family: Style.fontFamily
            font.pixelSize: 11
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            visible: root.tab !== 1
            height: 30; width: instLbl.implicitWidth + 16; radius: 8
            color: instMa.containsMouse ? Style.panelSuccessBg : Style.menuControlBg
            border.color: Style.menuSep
            Text { id: instLbl; anchors.centerIn: parent; text: "install"; color: Style.green; font.family: Style.fontFamily; font.pixelSize: 12 }
            MouseArea { id: instMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.applyQueue("install") }
          }
          Rectangle {
            visible: root.tab === 1
            height: 30; width: rmLbl.implicitWidth + 16; radius: 8
            color: rmMa.containsMouse ? Style.panelDangerBg : Style.menuControlBg
            border.color: Style.menuSep
            Text { id: rmLbl; anchors.centerIn: parent; text: "remove"; color: Style.red; font.family: Style.fontFamily; font.pixelSize: 12 }
            MouseArea { id: rmMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.applyQueue("remove") }
          }
          Rectangle {
            visible: root.tab === 2
            height: 30; width: upLbl.implicitWidth + 16; radius: 8
            color: upMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
            border.color: Style.menuSep
            Text { id: upLbl; anchors.centerIn: parent; text: "upgrade selected"; color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 12 }
            MouseArea { id: upMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.applyQueue("upgrade") }
          }
          Rectangle {
            visible: root.tab === 2
            height: 30; width: allLbl.implicitWidth + 16; radius: 8
            color: allMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
            border.color: Style.menuSep
            Text { id: allLbl; anchors.centerIn: parent; text: "upgrade all"; color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 12 }
            MouseArea { id: allMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.applyQueue("upgrade-all") }
          }
          Rectangle {
            height: 30; width: clrLbl.implicitWidth + 16; radius: 8
            color: clrMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
            border.color: Style.menuSep
            Text { id: clrLbl; anchors.centerIn: parent; text: "clear"; color: Style.menuInkDeep; font.family: Style.fontFamily; font.pixelSize: 12 }
            MouseArea { id: clrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearQueue() }
          }
        }

        Text {
          Layout.fillWidth: true
          text: "Install and remove run in Ghostty via sudo dnf — no password in Quickshell."
          color: Style.menuInkDeep
          font.family: Style.fontFamily
          font.pixelSize: 10
          opacity: 0.75
          wrapMode: Text.WordWrap
        }
      }
    }
    }
  }
}
