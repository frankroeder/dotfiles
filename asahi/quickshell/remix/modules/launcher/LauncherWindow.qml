import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../wallpaper" as Wallpaper

Scope {
  id: root

  property var theme: Wallpaper.DefaultTheme {}
  property bool shouldShow: false
  property string query: ""
  property int selectedIndex: 0
  property var launcherScreen: null
  property int resultCount: 0

  onResultCountChanged: {
    const max = Math.max(0, root.resultCount - 1)
    if (resultsList && resultsList.currentIndex > max && max >= 0) {
      resultsList.currentIndex = max
    }
  }

  function launchCurrent() {
    let entry = null
    if (resultsList && resultsList.currentItem && resultsList.currentItem.modelData) {
      entry = resultsList.currentItem.modelData
    } else if (filteredApps && filteredApps.values && resultsList.currentIndex < filteredApps.values.length) {
      entry = filteredApps.values[resultsList.currentIndex]
    }
    if (entry) root.launchApp(entry)
  }

  function openLauncher() {
    const mon = Hyprland.focusedMonitor
    launcherScreen = mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
    shouldShow = true
    searchInput.text = ""
    if (resultsList) resultsList.currentIndex = 0
    Qt.callLater(() => { if (searchInput) searchInput.forceActiveFocus() })
  }

  function closeLauncher() {
    shouldShow = false
  }

  function launchApp(entry) {
    if (entry && entry.execute) entry.execute()
    shouldShow = false
  }

  ScriptModel {
    id: filteredApps
    objectProp: "id"
    values: {
      let all = [...DesktopEntries.applications.values]
      all = all.filter(d => !d.noDisplay)
      const q = root.query.trim().toLowerCase()
      if (q === "") {
        return all.sort((a, b) => (a.name || "").localeCompare(b.name || ""))
      }
      const filtered = all.filter(d =>
        (d.name && d.name.toLowerCase().includes(q)) ||
        (d.genericName && d.genericName.toLowerCase().includes(q)) ||
        (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q))) ||
        (d.categories && d.categories.some(c => c.toLowerCase().includes(q)))
      )
      return filtered.sort((a, b) => {
        const an = (a.name || "").toLowerCase()
        const bn = (b.name || "").toLowerCase()
        const aStarts = an.startsWith(q)
        const bStarts = bn.startsWith(q)
        if (aStarts && !bStarts) return -1
        if (!aStarts && bStarts) return 1
        return an.localeCompare(bn)
      })
    }
  }

  PanelWindow {
    id: launcherPanel
    visible: root.shouldShow
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-launcher"
    exclusionMode: ExclusionMode.Ignore

    screen: root.launcherScreen

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Dark overlay backdrop
    MouseArea {
      anchors.fill: parent
      onClicked: root.shouldShow = false

      Rectangle {
        anchors.fill: parent
        color: root.theme.bgOverlay
      }
    }

    // Centered launcher box
    Rectangle {
      id: launcherBox
      anchors.centerIn: parent
      width: 580
      height: 480
      radius: 16
      color: root.theme.bgBase
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        Text {
          text: "Applications"
          color: root.theme.accentPrimary
          font.pixelSize: 14
          font.family: "Hack Nerd Font"
          font.bold: true
        }

        // Search bar
        Rectangle {
          Layout.fillWidth: true
          height: 44
          radius: 10
          color: root.theme.bgSurface
          border.color: searchInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
          border.width: 1

          Behavior on border.color {
            ColorAnimation { duration: 150 }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Text {
              text: "󰍉"
              color: root.theme.textMuted
              font.pixelSize: 18
              font.family: "Hack Nerd Font"
              Layout.alignment: Qt.AlignVCenter
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              color: root.theme.textPrimary
              font.pixelSize: 15
              font.family: "Hack Nerd Font"
              clip: true
              focus: true
              Accessible.role: Accessible.EditableText
              Accessible.name: "Search applications"

              Text {
                anchors.fill: parent
                text: "Type to search..."
                color: root.theme.textMuted
                font: parent.font
                visible: !parent.text && !parent.activeFocus
                verticalAlignment: Text.AlignVCenter
              }

              onTextChanged: {
                root.query = text
                if (resultsList) resultsList.currentIndex = 0
              }

              Keys.onEscapePressed: root.shouldShow = false
              Keys.onReturnPressed: root.launchCurrent()
              Keys.onEnterPressed: root.launchCurrent()

              Keys.onPressed: event => {
                const max = Math.max(0, root.resultCount - 1)
                if (event.key === Qt.Key_Down) {
                  event.accepted = true
                  resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, max)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                } else if (event.key === Qt.Key_Up) {
                  event.accepted = true
                  resultsList.currentIndex = Math.max(resultsList.currentIndex - 1, 0)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                } else if (event.key === Qt.Key_Tab) {
                  event.accepted = true
                  resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, max)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                }
              }
            }
          }
        }

        // Results count
        Text {
          text: root.resultCount + " application" + (root.resultCount !== 1 ? "s" : "")
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: "Hack Nerd Font"
        }

        // App list
        ListView {
          id: resultsList
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: filteredApps
          clip: true
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: 0
          highlightMoveDuration: 150
          highlightMoveVelocity: -1

          onCountChanged: root.resultCount = count
          onCurrentIndexChanged: if (currentIndex >= 0) root.selectedIndex = currentIndex

          highlight: Rectangle {
            radius: 8
            color: root.theme.bgSelected

            Rectangle {
              width: 3
              height: 24
              radius: 2
              color: root.theme.accentPrimary
              anchors.left: parent.left
              anchors.leftMargin: 2
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          delegate: Rectangle {
            id: delegateRoot
            required property var modelData
            required property int index

            Accessible.role: Accessible.Button
            Accessible.name: (modelData.name ?? "Application") + (modelData.genericName ? " - " + modelData.genericName : "")

            width: resultsList.width
            height: 44
            radius: 8
            color: hoverArea.containsMouse && resultsList.currentIndex !== index ? root.theme.bgHover : "transparent"

            Behavior on color {
              ColorAnimation { duration: 100 }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              // App icon
              Item {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter

                IconImage {
                  anchors.fill: parent
                  source: Quickshell.iconPath(delegateRoot.modelData.icon ?? "", true)
                  visible: (delegateRoot.modelData.icon ?? "") !== ""
                }

                // Fallback letter icon
                Text {
                  anchors.centerIn: parent
                  text: (delegateRoot.modelData.name ?? "?").charAt(0).toUpperCase()
                  color: root.theme.accentPrimary
                  font.pixelSize: 16
                  font.family: "Hack Nerd Font"
                  font.bold: true
                  visible: (delegateRoot.modelData.icon ?? "") === ""
                }
              }

              // App info
              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                  text: delegateRoot.modelData.name ?? ""
                  color: resultsList.currentIndex === delegateRoot.index ? root.theme.textPrimary : root.theme.textSecondary
                  font.pixelSize: 13
                  font.family: "Hack Nerd Font"
                  font.bold: resultsList.currentIndex === delegateRoot.index
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: delegateRoot.modelData.genericName ?? delegateRoot.modelData.comment ?? ""
                  color: root.theme.textMuted
                  font.pixelSize: 11
                  font.family: "Hack Nerd Font"
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              id: hoverArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launchApp(delegateRoot.modelData)
              onEntered: resultsList.currentIndex = delegateRoot.index
            }
          }

          // Empty state
          Text {
            anchors.centerIn: parent
            text: "No applications found"
            color: root.theme.textMuted
            font.pixelSize: 14
            font.family: "Hack Nerd Font"
            visible: root.resultCount === 0 && searchInput.text !== ""
          }
        }

        // Footer hint
        RowLayout {
          Layout.fillWidth: true
          spacing: 16

          Row {
            spacing: 4
            Rectangle {
              width: hintUp.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintUp; anchors.centerIn: parent; text: "↑↓"; color: root.theme.textMuted; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text { text: "navigate"; color: root.theme.textMuted; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEnter.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintEnter; anchors.centerIn: parent; text: "⏎"; color: root.theme.textMuted; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text { text: "launch"; color: root.theme.textMuted; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEsc.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintEsc; anchors.centerIn: parent; text: "esc"; color: root.theme.textMuted; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text { text: "close"; color: root.theme.textMuted; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Item { Layout.fillWidth: true }
        }
      }
    }
  }
}
