import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../"
import "../menu" as Menu

// Launchpad-style app grid (Super+Alt+Space; omarchy's shell/plugins/dock/AppGrid.qml): every app on one grid, A–Z.
// Typing filters (name start, then word start, then anywhere), arrows + Enter or a click launch, Esc clears the filter,
// then closes; a click on the scrim closes. Apps, hidden ids (launcher.hides), icons and launching (workspace,
// uwsm-app, usage count) are the launcher's.
Scope {
  id: root

  property var launcher: null
  property bool shown: false
  property var screen: null
  property string query: ""
  property Item hoverCell: null   // the cell under the pointer: lifts, and its windows show below it
  // Hover selects only after a real pointer move (the launcher's rule): Qt also sends enter / position events to a
  // cell rebuilt under a resting cursor, and Enter then launched that cell instead of the top match.
  property point lastPointer: Qt.point(NaN, NaN)
  function pointerMoved(g) {
    const seen = !isNaN(root.lastPointer.x)
    const moved = seen && (Math.abs(g.x - root.lastPointer.x) > 1 || Math.abs(g.y - root.lastPointer.y) > 1)
    if (!seen || moved) root.lastPointer = g
    return moved
  }

  function toggle() {
    if (root.shown) { root.shown = false; return }
    root.lastPointer = Qt.point(NaN, NaN)
    const l = root.launcher
    if (l && l.shouldShow) l.closeLauncher()
    if (l) l.launcherWorkspaceId = Hyprland.focusedWorkspace?.id ?? 1
    const mon = Hyprland.focusedMonitor
    root.screen = (mon && Quickshell.screens.find(s => s.name === mon.name)) || Quickshell.screens[0]
    root.query = ""
    root.openedAt = Date.now()
    root.shown = true
  }
  // Open ripple (Launchpad): the cells pop in from the centre outwards, delayed by their distance; cells rebuilt by
  // typing (later than 300 ms after the open) just appear. Off under reduced motion.
  property double openedAt: 0
  function launch(entry) {
    if (!entry || !root.launcher) return
    root.shown = false
    root.launcher.launchDesktopEntry(entry)
  }

  readonly property var apps: {
    const l = root.launcher
    if (!root.shown || !l) return []
    const _ = l.hiddenVersion + l.pinnedApps.length
    const q = root.query.trim().toLowerCase()
    const rank = d => {
      const n = String(d.name || "").toLowerCase()
      if (!q) return 1
      if (n.startsWith(q)) return 1
      if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 2
      if (n.includes(q) || String(d.genericName || "").toLowerCase().includes(q)) return 3
      return 0
    }
    return (DesktopEntries.applications.values || [])
      .filter(d => !d.noDisplay && !l.isHiddenApp(d))
      .map(d => ({ d: d, r: rank(d) }))
      .filter(x => x.r > 0)
      // Pinned apps lead, in pin order (without a query; with one they lead their match tier).
      .sort((a, b) => a.r - b.r || l.pinRank(a.d) - l.pinRank(b.d) || String(a.d.name).localeCompare(String(b.d.name)))
      .map(x => x.d)
  }

  PanelWindow {
    id: win
    visible: root.shown
    screen: root.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-appgrid"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { left: true; right: true; top: true; bottom: true }
    onVisibleChanged: if (visible) { search.text = ""; grid.currentIndex = 0; root.hoverCell = null; search.forceActiveFocus(); popIn.restart() }
    // The launcher's entry: scrim fades, card grows from the centre (no exit: the layer unmaps at once).
    ParallelAnimation {
      id: popIn
      Menu.MenuAnim { target: scrim; property: "opacity"; from: 0; to: 1; effects: true }
      Menu.MenuPopIn { target: card }
    }

    Rectangle {
      id: scrim
      anchors.fill: parent
      color: Style.menuDim
      MouseArea { anchors.fill: parent; onClicked: root.shown = false }
    }

    Rectangle {
      id: card
      readonly property int cols: Math.max(3, Math.min(7, Math.floor((win.width - 160) / grid.cellWidth)))
      width: cols * grid.cellWidth + 40
      height: Math.min(win.height - 160, 92 + 4 * grid.cellHeight)
      anchors.centerIn: parent
      radius: Style.menuPanelRadius
      color: Style.m3surface
      border.color: Style.popupBorder
      border.width: Style.popupBorderWidth
      MouseArea { anchors.fill: parent }   // a click on the card is no click on the scrim

      Text {
        id: glyph
        x: 24; y: 22
        text: "󰍉"
        font.family: Style.menuMono
        font.pixelSize: 20
        color: Style.m3onSurfaceVariant
      }
      TextInput {
        id: search
        anchors { left: glyph.right; leftMargin: 10; right: parent.right; rightMargin: 24; verticalCenter: glyph.verticalCenter }
        font.family: Style.menuSans
        font.pixelSize: 18
        color: Style.m3onSurface
        selectionColor: Style.m3primaryContainer
        clip: true
        onTextChanged: { root.query = text; grid.currentIndex = 0 }
        Keys.onPressed: (event) => {
          if (event.key === Qt.Key_Escape) {
            if (search.text) search.text = ""
            else root.shown = false
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.launch(root.apps[grid.currentIndex])
          } else if (event.key === Qt.Key_Left) grid.moveCurrentIndexLeft()
          else if (event.key === Qt.Key_Right) grid.moveCurrentIndexRight()
          else if (event.key === Qt.Key_Up) grid.moveCurrentIndexUp()
          else if (event.key === Qt.Key_Down) grid.moveCurrentIndexDown()
          else return
          event.accepted = true
        }
        Text {
          visible: !search.text
          text: "Search " + root.apps.length + " apps"
          font: search.font
          color: Style.m3onSurfaceVariant
        }
      }

      Menu.MenuEmptyState {
        anchors.centerIn: grid
        visible: root.apps.length === 0 && search.text !== ""
        glyph: "󰍉"
        tint: Style.m3primary
        title: "No app matches"
        detail: "Try another name."
      }

      GridView {
        id: grid
        anchors { fill: parent; topMargin: 64; leftMargin: 20; rightMargin: 20; bottomMargin: 16 }
        cellWidth: 132
        cellHeight: 124
        clip: true
        model: root.apps
        boundsBehavior: Flickable.StopAtBounds
        Menu.MenuEdgeFade { parent: grid; surface: Style.m3surface; atTop: true }
        Menu.MenuEdgeFade { parent: grid; surface: Style.m3surface }
        // The launcher's selection: accent tint + hairline, moved on the shared spring.
        highlightFollowsCurrentItem: false
        highlight: Rectangle {
          x: grid.currentItem ? grid.currentItem.x : 0
          y: grid.currentItem ? grid.currentItem.y : 0
          width: grid.cellWidth
          height: grid.cellHeight
          radius: Style.menuRadiusLg
          color: Style.menuSelFill
          border.color: Style.menuSelBorder
          border.width: 1
          Behavior on x { Menu.MenuAnim {} }
          Behavior on y { Menu.MenuAnim {} }
        }

        delegate: Item {
          id: cell
          required property var modelData
          required property int index
          width: grid.cellWidth
          height: grid.cellHeight
          readonly property bool hovered: root.hoverCell === cell
          property real enterT: 1
          opacity: Math.min(1, enterT)
          scale: 0.6 + 0.4 * enterT
          Component.onCompleted: {
            if (Style.reduceMotion || Date.now() - root.openedAt > 300) return
            const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
            const rows = Math.max(1, Math.min(4, Math.ceil(root.apps.length / cols)))
            const dx = cell.index % cols - (cols - 1) / 2
            const dy = Math.floor(cell.index / cols) - (rows - 1) / 2
            ripple.delay = Math.round(60 + Math.sqrt(dx * dx + dy * dy) * 55)
            cell.enterT = 0
            ripple.start()
          }
          SequentialAnimation {
            id: ripple
            property int delay: 0
            PauseAnimation { duration: ripple.delay }
            NumberAnimation { target: cell; property: "enterT"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
          }

          Image {
            id: icon
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
            // Hover lift: up 3 px, 1.06× (effects curve; runs once per enter / leave).
            transform: Translate { y: cell.hovered ? -3 : 0; Behavior on y { Menu.MenuAnim { effects: true } } }
            scale: cell.hovered ? 1.06 : 1
            Behavior on scale { Menu.MenuAnim { effects: true } }
            width: 56; height: 56
            sourceSize: Qt.size(112, 112)
            source: root.launcher ? root.launcher.resolveIconUrl(cell.modelData.icon) : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
          }
          Rectangle {   // no icon: the name's first letter
            visible: icon.status !== Image.Ready
            anchors.fill: icon
            radius: Style.menuRadiusMd
            color: Style.m3container
            Text {
              anchors.centerIn: parent
              text: String(cell.modelData.name || "?").charAt(0).toUpperCase()
              font.family: Style.menuSans
              font.pixelSize: 26
              color: Style.m3onSurface
            }
          }
          Rectangle {   // pinned: a small pin badge on the icon's corner (right-click toggles)
            visible: !!root.launcher && root.launcher.pinnedApps.length >= 0 && root.launcher.isPinned(cell.modelData)
            anchors { right: icon.right; top: icon.top; rightMargin: -6; topMargin: -6 }
            width: 22; height: 22; radius: 11
            color: Style.m3primary
            border.width: 2; border.color: Style.m3surfaceSolid
            Text { anchors.centerIn: parent; text: "󰐃"; color: Style.m3onPrimary; font.family: Style.menuMono; font.pixelSize: 12 }
          }
          Menu.MenuRunDots {   // a dot per open window; the focused app's first one an accent pill
            anchors { horizontalCenter: icon.horizontalCenter; top: icon.bottom; topMargin: 3 }
            count: root.launcher ? root.launcher.windowCount(cell.modelData) : 0
            active: !!root.launcher && root.launcher.isActive(cell.modelData)
          }
          Text {
            anchors { top: icon.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
            width: grid.cellWidth - 16
            text: cell.modelData.name || ""
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Style.menuSans
            font.pixelSize: 13
            color: Style.m3onSurface
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: if (containsMouse) root.hoverCell = cell; else if (root.hoverCell === cell) root.hoverCell = null
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPositionChanged: (mouse) => { if (root.pointerMoved(mapToGlobal(mouse.x, mouse.y))) grid.currentIndex = cell.index }
            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) { if (root.launcher) root.launcher.togglePin(cell.modelData) }
              else root.launch(cell.modelData)
            }
          }
        }
      }

      // The hovered app's open windows (≤ 3): title · workspace, under its cell (outside the grid's clip).
      Rectangle {
        id: winTip
        readonly property var wins: root.hoverCell && root.launcher ? root.launcher.windowsOf(root.hoverCell.modelData, 3) : []
        readonly property point at: {
          grid.contentY   // re-map when the grid scrolls under a resting pointer
          return root.hoverCell ? root.hoverCell.mapToItem(card, root.hoverCell.width / 2, root.hoverCell.height - 10) : Qt.point(0, 0)
        }
        visible: wins.length > 0
        width: Math.min(280, tipCol.implicitWidth + 20)
        height: tipCol.implicitHeight + 12
        x: Math.max(8, Math.min(card.width - width - 8, at.x - width / 2))
        y: Math.min(card.height - height - 8, at.y)
        radius: Style.menuRadiusMd
        color: Style.m3containerHigh
        border.color: Style.menuHairline
        border.width: 1
        Column {
          id: tipCol
          x: 10; y: 6
          spacing: 2
          Repeater {
            model: winTip.wins
            Row {
              required property var modelData
              spacing: 8
              Text {
                width: Math.min(implicitWidth, 200)
                text: modelData.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Style.fontUi; font.pixelSize: Style.typeBody
                color: Style.m3onSurface
              }
              Text {
                text: modelData.ws ? "ws " + modelData.ws : ""
                font.family: Style.fontUi; font.pixelSize: Style.typeCaption; font.features: Style.fontTabular
                color: Style.m3onSurfaceVariant
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }
    }
  }
}
