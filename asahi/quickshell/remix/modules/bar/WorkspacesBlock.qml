import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import "../../"

Item {
  id: root

  required property var controller

  readonly property int pad: 3
  readonly property int pillH: Style.barHeight - 2 * Style.barChipInset - 2 * pad
  readonly property int numW: 26
  readonly property int iconStep: Style.barWsIcon + 3
  readonly property int maxIcons: 4
  readonly property int gap: 2
  readonly property int dur: 300

  // One step per wheel notch (120): trackpad swipes accumulate, horizontal ones are ignored.
  property real wheelAcc: 0
  function wheelStep(wheel) {
    if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) return
    root.wheelAcc += wheel.angleDelta.y
    if (Math.abs(root.wheelAcc) < 120) return
    root.controller.cycleWorkspace(root.wheelAcc < 0)
    root.wheelAcc = 0
  }

  // Icons on every workspace (click the active one); a flag file, so all bars share it across restarts.
  readonly property string showAllFlag: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
    + "/asahi/bar-workspace-icons"
  property bool showAll: false
  // BarHost's budget for this block: the flag's icons on every workspace show only while they fit in it
  // (ten occupied workspaces beside the notch pushed the CPU chip half under the cutout's wall).
  property real maxWidth: Infinity
  readonly property bool iconsAll: root.showAll && root.blockWidth(true) <= root.maxWidth
  FileView {
    path: root.showAllFlag
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.showAll = true
    onLoadFailed: root.showAll = false
  }
  function toggleShowAll() {
    Quickshell.execDetached(["sh", "-c", 'if [ -e "$1" ]; then rm -f "$1"; else mkdir -p "${1%/*}" && : > "$1"; fi', "sh", root.showAllFlag])
  }

  readonly property var hyprMonitor: controller.barScreen ? Hyprland.monitorFor(controller.barScreen) : null
  readonly property bool monitorFocused: !hyprMonitor || Hyprland.focusedMonitor === hyprMonitor
  readonly property int activeWorkspaceId: (controller.wsWindowVersion,
    hyprMonitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? 1)
  readonly property var visibleWorkspaces: {
    controller.wsWindowVersion
    const ids = new Set([root.activeWorkspaceId])
    for (const t of controller.hyprClients) {
      const id = t.workspace?.id
      if (id != null && id > 0 && (!hyprMonitor || t.monitor === hyprMonitor.id)) ids.add(id)
    }
    return Array.from(ids).sort((a, b) => a - b)
  }

  function workspaceWindows(wsId) {
    controller.wsWindowVersion
    return controller.hyprClients.filter(t => t.workspace?.id === wsId)
  }

  function appGroups(wsId) {
    const groups = []
    for (const t of root.workspaceWindows(wsId)) {
      const key = String(t.class || t.initialClass || t.address).toLowerCase()
      const g = groups.find(g => g.key === key)
      if (g) g.count++
      else groups.push({ key: key, count: 1, client: t })
    }
    return groups
  }

  function stateGlyph(wsId) {
    const wins = root.workspaceWindows(wsId)
    if (wins.length === 0) return ""
    const bare = a => String(a || "").replace(/^0x/, "")
    const act = bare(Hyprland.activeToplevel?.address)
    const w = wins.find(t => bare(t.address) === act) || wins.reduce((a, b) => b.focusHistoryID < a.focusHistoryID ? b : a)
    if (w.fullscreen & 2) return String.fromCodePoint(0xF0293)
    if (w.fullscreen & 1) return String.fromCodePoint(0xF05AF)
    if (w.pinned) return String.fromCodePoint(0xF0E57)
    if (w.floating) return String.fromCodePoint(0xF05B2)
    if ((w.grouped || []).length > 0) return String.fromCodePoint(0xF04E9)
    return String.fromCodePoint(0xF056E)
  }

  // `all` = with icons on every workspace; left out, as shown.
  function itemWidth(wsId, all) {
    const active = wsId === root.activeWorkspaceId
    const n = root.appGroups(wsId).length
    if (n === 0) return active ? root.pillH : root.numW
    if (!active && !(all === undefined ? root.iconsAll : all)) return root.numW
    return root.numW + Math.min(n, root.maxIcons) * root.iconStep + (n > root.maxIcons ? root.iconStep : 0) + 4
  }
  function blockWidth(all) {
    let w = 0
    for (const id of root.visibleWorkspaces) w += root.itemWidth(id, all) + root.gap
    return w - root.gap + 2 * root.pad
  }

  // Final, not animated, width: BarHost's Row then runs its chipMove once per change.
  implicitWidth: root.blockWidth(root.iconsAll)
  implicitHeight: Style.barHeight - 2 * Style.barChipInset

  MouseArea {
    anchors.fill: parent
    onWheel: wheel => root.wheelStep(wheel)
  }

  // The capsule is the hull of two copies of the target span: one on the duration + easing of the item widths and
  // BarHost's chipMove, one 1.5× slower. So the leading edge moves with everything else and the trailing edge lags:
  // it stretches toward the new workspace and settles there (Menu.MenuStretchPill's look; no direction logic).
  Rectangle {
    id: capsule
    readonly property int activeIndex: root.visibleWorkspaces.indexOf(root.activeWorkspaceId)
    readonly property real targetLeft: {
      let x = root.pad
      for (let i = 0; i < activeIndex; i++) x += root.itemWidth(root.visibleWorkspaces[i]) + root.gap
      return x
    }
    readonly property real targetRight: targetLeft + (activeIndex >= 0 ? root.itemWidth(root.activeWorkspaceId) : 0)
    readonly property int slowDur: Style.reduceMotion ? root.dur : root.dur * 1.5
    property real fastLeft: targetLeft
    property real fastRight: targetRight
    property real slowLeft: targetLeft
    property real slowRight: targetRight
    readonly property real edgeLeft: Math.min(fastLeft, slowLeft)
    readonly property real edgeRight: Math.max(fastRight, slowRight)
    x: edgeLeft
    anchors.verticalCenter: parent.verticalCenter
    width: edgeRight - edgeLeft
    height: root.pillH
    radius: Style.radiusSm - 1
    visible: activeIndex >= 0
    opacity: root.monitorFocused ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: root.dur } }

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Style.wsActive }
      GradientStop { position: 1.0; color: Style.wsActiveAlt }
    }

    Behavior on fastLeft { NumberAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on fastRight { NumberAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on slowLeft { NumberAnimation { duration: capsule.slowDur; easing.type: Easing.OutCubic } }
    Behavior on slowRight { NumberAnimation { duration: capsule.slowDur; easing.type: Easing.OutCubic } }
  }

  Row {
    x: root.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.gap

    Repeater {
      // ScriptModel diffs the ids, so items survive refreshes and can animate open/closed.
      model: ScriptModel { values: root.visibleWorkspaces }

      Item {
        id: wsButton
        required property int modelData
        readonly property int wsId: modelData
        readonly property bool isFocused: root.activeWorkspaceId === wsId
        readonly property var groups: root.appGroups(wsId)
        readonly property bool showIcons: isFocused || root.iconsAll
        readonly property int overflowCount: Math.max(0, groups.length - root.maxIcons)
        readonly property string glyph: root.stateGlyph(wsId)

        width: root.itemWidth(wsId)
        height: root.pillH
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        Behavior on width { NumberAnimation { duration: root.dur; easing.type: Easing.OutCubic } }

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusSm - 1
          color: Style.wsHoverBg
          opacity: wsMouse.containsMouse && !wsButton.isFocused ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
        }

        // The label changes exactly where the capsule covers it: two copies, each clipped to its side of the capsule's
        // edge (no colour fade, no layer) — bare = the number, under the capsule = the state glyph in the capsule's ink.
        // capL..capR = the covered span of the label; the capsule is never narrower than a label.
        readonly property int labelW: isFocused && groups.length === 0 ? root.pillH : root.numW
        readonly property real capL: Math.max(0, Math.min(labelW, capsule.edgeLeft - root.pad - x))
        readonly property real capR: Math.max(0, Math.min(labelW, capsule.edgeRight - root.pad - x))
        Repeater {
          model: 2
          Item {
            id: labelClip
            required property int index
            readonly property bool covered: index === 1
            readonly property bool asGlyph: covered && wsButton.glyph !== ""
            x: covered ? wsButton.capL : wsButton.capL > 0 ? 0 : wsButton.capR
            width: covered ? wsButton.capR - wsButton.capL : wsButton.capL > 0 ? wsButton.capL : wsButton.labelW - wsButton.capR
            height: wsButton.height
            clip: true
            Text {
              x: -labelClip.x
              width: wsButton.labelW
              height: parent.height
              text: labelClip.asGlyph ? wsButton.glyph : wsButton.wsId
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              color: labelClip.covered ? Style.wsBadgeActiveText : Style.wsOccupiedText
              opacity: labelClip.covered || wsMouse.containsMouse ? 1 : 0.7
              font { family: Style.fontFamily; pixelSize: labelClip.asGlyph ? 18 : (wsButton.wsId >= 10 ? 12 : 13); bold: true }
              Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
            }
          }
        }

        // A window here wants attention (bell, finished build): static dot, one pop; focusing the window clears it.
        Rectangle {
          readonly property bool on: !wsButton.isFocused && (Hyprland.workspaces.values.find(w => w.id === wsButton.wsId)?.urgent ?? false)
          x: root.numW - 8
          y: 5
          width: 5
          height: 5
          radius: 2.5
          color: Style.red
          scale: on ? 1 : 0
          visible: scale > 0
          Behavior on scale { NumberAnimation { duration: Style.reduceMotion ? 0 : Style.menuAnimMs; easing.type: Easing.OutBack } }
        }

        Row {
          x: root.numW
          anchors.verticalCenter: parent.verticalCenter
          spacing: root.iconStep - Style.barWsIcon

          Repeater {
            model: ScriptModel { values: wsButton.groups.slice(0, root.maxIcons).map(g => g.key) }

            Item {
              id: appSlot
              required property string modelData
              required property int index
              readonly property var group: wsButton.groups.find(g => g.key === modelData)
              readonly property var client: group ? group.client : null
              readonly property int count: group ? group.count : 1
              readonly property bool shown: wsButton.showIcons
              width: Style.barWsIcon
              height: Style.barWsIcon
              opacity: shown ? (wsButton.isFocused ? 1 : 0.85) : 0
              scale: shown ? 1 : 0.4
              transformOrigin: Item.Left

              // Staggered open, quick close.
              Behavior on opacity {
                SequentialAnimation {
                  PauseAnimation { duration: appSlot.shown ? 40 + Math.max(0, appSlot.index) * 45 : 0 }
                  NumberAnimation { duration: appSlot.shown ? 180 : 90; easing.type: Easing.OutCubic }
                }
              }
              Behavior on scale {
                SequentialAnimation {
                  PauseAnimation { duration: appSlot.shown ? 40 + Math.max(0, appSlot.index) * 45 : 0 }
                  NumberAnimation { duration: appSlot.shown ? 260 : 120; easing.type: appSlot.shown ? Easing.OutBack : Easing.OutCubic }
                }
              }

              NumberAnimation { id: popIn; target: appSlot; property: "scale"; from: 0.3; to: 1; duration: 320; easing.type: Easing.OutBack }
              Component.onCompleted: if (shown) popIn.start()

              IconImage {
                id: appIcon
                anchors.fill: parent
                source: { controller.wsWindowVersion; return appSlot.client ? controller.appIconSource(appSlot.client) : "" }
                visible: status === Image.Ready
              }

              Text {
                anchors.fill: parent
                visible: !appIcon.visible
                text: { controller.wsWindowVersion; return appSlot.client ? controller.appFallbackText(appSlot.client) : "" }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: wsButton.isFocused ? Style.wsBadgeActiveText : Style.textAlt
                font { family: Style.fontFamily; pixelSize: 11; bold: true }
              }

              Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -3
                anchors.bottomMargin: -2
                width: Math.max(height, countText.implicitWidth + 4)
                height: 11
                radius: height / 2
                color: wsButton.isFocused ? Style.wsBadgeActiveText : Style.text
                visible: appSlot.count > 1

                Text {
                  id: countText
                  anchors.centerIn: parent
                  text: appSlot.count
                  color: wsButton.isFocused ? Style.wsActive : Style.crust
                  font { family: Style.fontFamily; pixelSize: 8; bold: true }
                }
              }
            }
          }

          Text {
            visible: wsButton.overflowCount > 0
            width: root.iconStep
            height: Style.barWsIcon
            text: "+" + wsButton.overflowCount
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: wsButton.isFocused ? Style.wsBadgeActiveText : Style.textAlt
            opacity: wsButton.showIcons ? 0.85 : 0
            font { family: Style.fontFamily; pixelSize: 11; bold: true }
            Behavior on opacity { NumberAnimation { duration: 180 } }
          }
        }

        MouseArea {
          id: wsMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton
          onClicked: {
            if (wsButton.isFocused && root.monitorFocused) root.toggleShowAll()
            else controller.activateWorkspace(wsButton.wsId)
          }
          onWheel: wheel => root.wheelStep(wheel)
        }
      }
    }
  }
}
