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

  function itemWidth(wsId) {
    const active = wsId === root.activeWorkspaceId
    const n = root.appGroups(wsId).length
    if (n === 0) return active ? root.pillH : root.numW
    if (!active && !root.showAll) return root.numW
    return root.numW + Math.min(n, root.maxIcons) * root.iconStep + (n > root.maxIcons ? root.iconStep : 0) + 4
  }

  // Final, not animated, width: BarHost's Row then runs its chipMove once per change.
  implicitWidth: {
    let w = 0
    for (const id of root.visibleWorkspaces) w += root.itemWidth(id) + root.gap
    return w - root.gap + 2 * root.pad
  }
  implicitHeight: Style.barHeight - 2 * Style.barChipInset

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Style.barGroupBg
    border.width: 1
    border.color: Style.barGroupBorder
  }

  MouseArea {
    anchors.fill: parent
    onWheel: wheel => root.wheelStep(wheel)
  }

  // Same duration + easing as the item widths and BarHost's chipMove, so everything moves together.
  Rectangle {
    id: capsule
    readonly property int activeIndex: root.visibleWorkspaces.indexOf(root.activeWorkspaceId)
    x: {
      let x = root.pad
      for (let i = 0; i < activeIndex; i++) x += root.itemWidth(root.visibleWorkspaces[i]) + root.gap
      return x
    }
    anchors.verticalCenter: parent.verticalCenter
    width: activeIndex >= 0 ? root.itemWidth(root.activeWorkspaceId) : 0
    height: root.pillH
    radius: height / 2
    visible: activeIndex >= 0
    opacity: root.monitorFocused ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: root.dur } }

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Style.wsActive }
      GradientStop { position: 1.0; color: Style.wsActiveAlt }
    }

    Behavior on x { NumberAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: root.dur; easing.type: Easing.OutCubic } }
  }

  Row {
    id: wsContent
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
        readonly property bool showIcons: isFocused || root.showAll
        readonly property int overflowCount: Math.max(0, groups.length - root.maxIcons)
        readonly property string glyph: isFocused ? root.stateGlyph(wsId) : ""

        width: root.itemWidth(wsId)
        height: root.pillH
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        Behavior on width { NumberAnimation { duration: root.dur; easing.type: Easing.OutCubic } }

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: Style.wsHoverBg
          opacity: wsMouse.containsMouse && !wsButton.isFocused ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Text {
          width: wsButton.isFocused && wsButton.groups.length === 0 ? root.pillH : root.numW
          height: parent.height
          text: wsButton.glyph !== "" ? wsButton.glyph : wsButton.wsId
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          color: wsButton.isFocused ? Style.wsBadgeActiveText : Style.wsOccupiedText
          opacity: wsButton.isFocused || wsMouse.containsMouse ? 1 : 0.7
          font { family: Style.fontFamily; pixelSize: wsButton.glyph !== "" ? 18 : (wsButton.wsId >= 10 ? 12 : 13); bold: true }
          Behavior on color { ColorAnimation { duration: root.dur } }
          Behavior on opacity { NumberAnimation { duration: 120 } }
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
