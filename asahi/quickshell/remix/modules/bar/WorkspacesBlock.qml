import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../"

// Workspace capsules with app icons beside each workspace number (left side of solid bar).
Item {
  id: root

  required property var controller

  readonly property int focusedWorkspaceId: (controller.wsWindowVersion, Hyprland.focusedWorkspace?.id ?? 1)
  readonly property var visibleWorkspaces: {
    controller.wsWindowVersion
    const ids = new Set()
    const focused = Hyprland.focusedWorkspace?.id
    if (focused != null) ids.add(focused)
    for (const t of controller.hyprClients) {
      const id = t.workspace?.id
      if (id != null && id > 0) ids.add(id)
    }
    return Array.from(ids).sort((a, b) => a - b)
  }

  function workspaceWindows(wsId) {
    controller.wsWindowVersion
    return controller.hyprClients.filter(t => t.workspace?.id === wsId)
  }

  function workspaceVisibleElsewhere(wsId) {
    const monitors = Hyprland.monitors?.values || []
    return monitors.some(m => (m.activeWorkspace?.id === wsId) && wsId !== root.focusedWorkspaceId)
  }

  readonly property bool hasSpecialWorkspace: {
    controller.wsWindowVersion
    return controller.hyprClients.some(t => String(t.workspace?.name || "").startsWith("special:"))
  }

  implicitWidth: workspacesBlock.implicitWidth
  implicitHeight: workspacesBlock.implicitHeight

  Rectangle {
    id: workspacesBlock
    anchors.verticalCenter: parent.verticalCenter
    color: Qt.alpha(Style.text, 0.05)
    radius: Style.radiusSm
    border.width: 1
    border.color: Qt.alpha(Style.text, 0.08)
    implicitHeight: Style.barHeight - 2
    implicitWidth: wsContent.implicitWidth + 10 + (specialBadge.visible ? 28 : 0)

    Rectangle {
      id: activeWsHighlight
      readonly property int activeIndex: root.visibleWorkspaces.indexOf(root.focusedWorkspaceId)
      readonly property var activeItem: (wsRepeater.count, activeIndex >= 0 ? wsRepeater.itemAt(activeIndex) : null)
      readonly property real targetLeft: activeItem ? wsContent.x + activeItem.x : wsContent.x
      readonly property real targetRight: targetLeft + (activeItem ? activeItem.width : 0)
      property real actualLeft: targetLeft
      property real actualRight: targetRight
      property int prevIndex: activeIndex
      property int leftDuration: 180
      property int rightDuration: 180

      function tuneEdgeMotion() {
        if (activeIndex > prevIndex) {
          leftDuration = 260
          rightDuration = 135
        } else if (activeIndex < prevIndex) {
          leftDuration = 135
          rightDuration = 260
        } else {
          leftDuration = 180
          rightDuration = 180
        }
        prevIndex = activeIndex
      }

      onTargetLeftChanged: {
        tuneEdgeMotion()
        actualLeft = targetLeft
      }
      onTargetRightChanged: actualRight = targetRight

      x: actualLeft
      y: (workspacesBlock.height - height) / 2
      width: Math.max(0, actualRight - actualLeft)
      height: workspacesBlock.height - 6
      radius: Style.radiusSm
      color: Style.wsActive
      border.width: 1
      border.color: Style.wsActiveBorder
      visible: activeItem !== null
      z: 0

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Style.wsActive }
        GradientStop { position: 1.0; color: Style.wsActiveAlt }
      }

      Behavior on actualLeft { NumberAnimation { duration: activeWsHighlight.leftDuration; easing.type: Easing.OutCubic } }
      Behavior on actualRight { NumberAnimation { duration: activeWsHighlight.rightDuration; easing.type: Easing.OutCubic } }
    }

    Row {
      id: wsContent
      anchors.left: parent.left
      anchors.leftMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      z: 1

      Repeater {
        id: wsRepeater
        model: root.visibleWorkspaces

        Rectangle {
          id: wsButton
          required property int modelData
          readonly property int wsId: modelData
          readonly property bool isFocused: root.focusedWorkspaceId === wsId
          readonly property var windows: root.workspaceWindows(wsId)
          readonly property bool isOccupied: windows.length > 0
          readonly property bool isHovered: wsMouse.containsMouse
          readonly property bool isVisibleElsewhere: root.workspaceVisibleElsewhere(wsId)
          readonly property int iconLimit: isFocused ? 4 : 3
          readonly property var shownWindows: windows.slice(0, iconLimit)
          readonly property int overflowCount: Math.max(0, windows.length - shownWindows.length)

          implicitWidth: wsInner.implicitWidth + 8
          implicitHeight: workspacesBlock.height - 6
          radius: Style.radiusSm
          color: isFocused ? "transparent" : (isHovered ? Style.wsHoverBg : (isVisibleElsewhere ? Style.wsVisibleBg : (isOccupied ? Style.wsOccupiedBg : Style.wsEmptyBg)))
          border.width: 1
          border.color: isFocused ? "transparent" : (isVisibleElsewhere ? Style.wsVisibleBorder : Style.wsInactiveBorder)

          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }

          Row {
            id: wsInner
            anchors.centerIn: parent
            spacing: 4

            Rectangle {
              width: 22
              height: 22
              radius: 11
              color: isFocused
                ? Style.wsBadgeActiveBg
                : (wsButton.isHovered ? Style.wsBadgeHoverBg : (wsButton.isVisibleElsewhere ? Style.wsBadgeVisibleBg : (wsButton.isOccupied ? Style.wsBadgeOccupiedBg : Style.wsBadgeEmptyBg)))
              border.width: 1
              border.color: isFocused ? Style.wsBadgeActiveBorder : Style.wsBadgeBorder

              Text {
                anchors.fill: parent
                text: wsButton.wsId
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: isFocused ? Style.wsBadgeActiveText : (wsButton.isVisibleElsewhere ? Style.sky : (wsButton.isOccupied ? Style.wsOccupiedText : Style.wsEmptyText))
                font { family: Style.fontFamily; pixelSize: wsButton.wsId >= 10 ? 10 : 11; bold: true }
              }
            }

            Repeater {
              model: wsButton.shownWindows

              Item {
                width: 22
                height: 22

                IconImage {
                  id: appIcon
                  anchors.centerIn: parent
                  width: 18
                  height: 18
                  source: { controller.wsWindowVersion; return controller.appIconSource(modelData) }
                  visible: status === Image.Ready
                }

                Text {
                  anchors.fill: parent
                  visible: !appIcon.visible
                  text: { controller.wsWindowVersion; return controller.appFallbackText(modelData) }
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  color: wsButton.isFocused ? Style.crust : Style.textAlt
                  font { family: Style.fontFamily; pixelSize: 10; bold: true }
                }
              }
            }

            Rectangle {
              visible: wsButton.overflowCount > 0
              width: visible ? 22 : 0
              height: 22
              radius: 11
              color: Qt.alpha(Style.text, 0.10)
              border.width: 1
              border.color: Qt.alpha(Style.text, 0.18)

              Text {
                anchors.centerIn: parent
                text: "+" + wsButton.overflowCount
                color: wsButton.isFocused ? Style.crust : Style.textMuted
                font { family: Style.fontFamily; pixelSize: 9; bold: true }
              }
            }
          }

          MouseArea {
            id: wsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: controller.activateWorkspace(wsButton.wsId)
            onWheel: wheel => controller.cycleWorkspace(wheel.angleDelta.y < 0)
          }
        }
      }
    }

    Rectangle {
      id: specialBadge
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      width: 22
      height: 22
      radius: Style.radiusSm
      visible: root.hasSpecialWorkspace
      color: Style.panelAccentBg
      border.width: 1
      border.color: Style.panelAccentBorder
      z: 2

      Text {
        anchors.centerIn: parent
        text: "S"
        color: Style.sky
        font { family: Style.fontFamily; pixelSize: 10; bold: true }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "scratch"])
        onWheel: wheel => controller.cycleWorkspace(wheel.angleDelta.y < 0)
      }
    }
  }
}
