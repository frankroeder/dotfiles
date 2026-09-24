import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "wallpaper_thumbs.js" as WallThumbs
import "../menu" as Menu
import "../../"

// Wallpaper picker (Super+Shift+W): a skewed window carousel over the desktop,
// live preview on the centre window; "All" expands the filter and the full grid.
Scope {
  id: root

  property string searchText: ""
  property bool showAll: false
  property string previewPath: ""
  property var pickerScreen: null
  readonly property string uiFont: Style.menuMono

  IpcHandler {
    target: "wallpaper"
    function toggle(): void {
      if (!wallpaperPanel.visible) {
        // Open on the focused monitor, like the launcher.
        const mon = Hyprland.focusedMonitor
        root.pickerScreen = (mon && Quickshell.screens.find(s => s.name === mon.name)) || Quickshell.screens[0] || null
      }
      wallpaperPanel.visible = !wallpaperPanel.visible
      if (wallpaperPanel.visible) {
        root.searchText = ""
        root.previewPath = ""
        root.showAll = false
        if (WallpaperService.wallpapers.length === 0) WallpaperService.rescan()
        wallCarousel.placed = false
        Qt.callLater(wallCarousel.place)
        wallBox.forceActiveFocus()
      } else {
        WallpaperService.stopPreview()
      }
    }
    function random(): void {
      const p = WallpaperService.randomWallpaper()
      if (p) WallpaperService.setWallpaper(p)
    }
  }

  property var filteredWallpapers: WallpaperService.arranged(root.searchText)

  function close() {
    WallpaperService.stopPreview()
    wallpaperPanel.visible = false
  }

  // Fullscreen fade of the preview wallpaper (above hyprpaper, below windows)
  // so carousel browse does not pop the desktop. Starts after previewWaitMs.
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: 0
      focusable: false
      mask: Region {}
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "asahi-wall-preview"
      anchors { left: true; right: true; top: true; bottom: true }
      visible: fadeImg.opacity > 0.01 || WallpaperService.previewApplied

      Image {
        id: fadeImg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Math.max(1, modelData.width)
        sourceSize.height: Math.max(1, modelData.height)
        source: WallpaperService.fadePath ? ("file://" + WallpaperService.fadePath) : ""
        readonly property bool show: WallpaperService.previewApplied && fadeImg.status === Image.Ready
        opacity: fadeImg.show ? 1 : 0
        scale: fadeImg.show ? 1 : 1.04
        Behavior on opacity {
          NumberAnimation { duration: WallpaperService.previewFadeMs; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
          NumberAnimation { duration: WallpaperService.previewFadeMs + 80; easing.type: Easing.OutCubic }
        }
      }
    }
  }
  function setShowAll(on) {
    root.showAll = on
    if (on) wallSearchInput.forceActiveFocus()
    else { root.searchText = ""; wallSearchInput.text = ""; wallBox.forceActiveFocus() }
  }
  // Shared by the card and the search field: Shift arms live preview, ←/→ or
  // Ctrl+h/j/k/l browse, ⏎ applies, Esc unwinds.
  // `typing` is the search field, where Shift is just a modifier for capitals —
  // only the Shift+arrow form arms live preview there.
  function handleKey(event, typing) {
    const ctrl = !!(event.modifiers & Qt.ControlModifier)
    const shift = !!(event.modifiers & Qt.ShiftModifier)
    const left = event.key === Qt.Key_Left || (ctrl && (event.key === Qt.Key_H || event.key === Qt.Key_K))
    const right = event.key === Qt.Key_Right || (ctrl && (event.key === Qt.Key_L || event.key === Qt.Key_J))
    if (event.key === Qt.Key_Shift) {
      if (typing || event.isAutoRepeat) return false
      WallpaperService.setLive(!WallpaperService.liveMode)
      return true
    }
    if (shift && (left || right)) WallpaperService.setLive(true)
    if (event.key === Qt.Key_Escape) {
      if (root.previewPath !== "") root.previewPath = ""
      else if (WallpaperService.liveMode) WallpaperService.setLive(false)
      else if (root.showAll) root.setShowAll(false)
      else root.close()
      return true
    }
    if (left) { wallCarousel.prev(); return true }
    if (right) { wallCarousel.next(); return true }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { wallCarousel.activate(); return true }
    return false
  }

  PanelWindow {
    id: wallpaperPanel
    visible: false
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    screen: root.pickerScreen

    anchors { top: true; bottom: true; left: true; right: true }

    Menu.MenuBackdrop { reveal: wallpaperPanel.visible ? 1 : 0 }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Item {
      id: wallStage
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(Math.max(0, parent.width - 48), 1680)
      height: wallCarousel.height + (wallCarousel.height > 0 ? 16 : 0) + wallBox.height
      y: Math.max(36, Math.round((parent.height - height) / 2))

      WallpaperCarousel {
        id: wallCarousel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        paths: root.filteredWallpapers
        viewW: parent.width
        anchorPath: WallpaperService.currentWallpaper
        live: wallpaperPanel.visible
        fontFamily: Style.menuSans
        iconFamily: root.uiFont
        onActivated: function(p) { WallpaperService.setWallpaper(p); root.close() }
      }

      Menu.MenuCard {
        id: wallBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: wallCarousel.bottom
        anchors.topMargin: wallCarousel.height > 0 ? 16 : 0
        width: Math.min(1040, parent.width)
        height: wallCol.implicitHeight + 34
        cardMargin: 17
        focus: true
        Behavior on height { Menu.MenuAnim {} }
        Keys.onPressed: event => { if (root.handleKey(event)) event.accepted = true }

        ColumnLayout {
          id: wallCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            // MenuHeader sizes itself from its parent; give it a fixed slot so the
            // RowLayout does not rearrange recursively.
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 28
              Menu.MenuHeader {
                anchors.fill: parent
                title: "Wallpapers"
                subtitle: (root.filteredWallpapers || []).length === WallpaperService.wallpapers.length
                  ? WallpaperService.wallpapers.length + " images"
                  : (root.filteredWallpapers || []).length + " of " + WallpaperService.wallpapers.length + " images"
              }
            }
            WallpaperChip {
              glyph: "󰐊"
              label: "Live"
              on: WallpaperService.liveMode
              fontFamily: Style.menuSans
              iconFamily: root.uiFont
              onClicked: WallpaperService.setLive(!WallpaperService.liveMode)
            }
            WallpaperChip {
              glyph: root.showAll ? "󰅃" : "󰅀"
              label: "All"
              on: root.showAll
              fontFamily: Style.menuSans
              iconFamily: root.uiFont
              onClicked: root.setShowAll(!root.showAll)
            }
            Rectangle {
              width: 28; height: 28; radius: 14
              color: refreshMa.containsMouse ? Style.m3containerHigh : Style.m3container
              Text { anchors.centerIn: parent; text: "󰑐"; color: Style.m3onSurfaceVariant; font.pixelSize: 14; font.family: root.uiFont }
              MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperService.rescan() }
            }
          }

          Menu.MenuDivider { Layout.fillWidth: true; Layout.preferredHeight: 1 }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰍉"; color: Style.m3onSurfaceVariant; font.family: root.uiFont; font.pixelSize: 13 }
            Text {
              Layout.fillWidth: true
              text: (wallCarousel.currentPath || "").split("/").pop() || "—"
              color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideMiddle
            }
            Rectangle {
              implicitWidth: shuffleRow.implicitWidth + 22; implicitHeight: 30; radius: Style.menuRadiusFull
              color: shuffleMa.containsMouse ? Style.m3containerHigh : Style.m3container
              Row {
                id: shuffleRow; anchors.centerIn: parent; spacing: 6
                Text { text: "󰒝"; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Shuffle"; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: 12; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea { id: shuffleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wallCarousel.jumpTo(WallpaperService.randomWallpaper()) }
            }
            Rectangle {
              implicitWidth: applyRow.implicitWidth + 22; implicitHeight: 30; radius: Style.menuRadiusFull
              color: applyMa.containsMouse ? Qt.lighter(Style.m3primary, 1.1) : Style.m3primary
              Row {
                id: applyRow; anchors.centerIn: parent; spacing: 6
                Text { text: "󰄬"; color: Style.m3onPrimary; font.family: root.uiFont; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Apply"; color: Style.m3onPrimary; font.family: Style.menuSans; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
              }
              MouseArea { id: applyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wallCarousel.activate() }
            }
          }

          WallpaperFilterBar {
            Layout.fillWidth: true
            query: root.searchText
            fontFamily: Style.menuSans
            iconFamily: root.uiFont
          }

          WallpaperPalette {
            Layout.fillWidth: true
            path: wallCarousel.currentPath
            fontFamily: Style.menuSans
            iconFamily: root.uiFont
          }

          Menu.MenuDivider { Layout.fillWidth: true; Layout.preferredHeight: 1 }

          WallpaperFlavors {
            Layout.fillWidth: true
            fontFamily: Style.menuSans
            iconFamily: root.uiFont
          }

          // Expanded: filter + full grid (click applies, right-click previews full size).
          ColumnLayout {
            visible: root.showAll
            Layout.fillWidth: true
            spacing: 12

            Menu.MenuDivider { Layout.fillWidth: true; Layout.preferredHeight: 1 }

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 34
              radius: 17
              color: Style.m3container
              Text {
                id: wallSearchGlyph
                anchors.left: parent.left; anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"; color: Style.m3onSurfaceVariant; font.family: root.uiFont; font.pixelSize: 14
              }
              TextInput {
                id: wallSearchInput
                anchors.left: wallSearchGlyph.right; anchors.leftMargin: 10
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Style.m3onSurface
                font.family: Style.menuSans
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onTextChanged: root.searchText = text
                Keys.onPressed: event => { if (root.handleKey(event, true)) event.accepted = true }
                Text {
                  anchors.fill: parent
                  text: "Filter wallpapers"
                  color: Style.m3onSurfaceVariant
                  font: parent.font
                  visible: !parent.text && !parent.activeFocus
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: Math.min(380, Math.round(wallpaperPanel.height * 0.36))
              clip: true

              GridView {
                id: wallpaperGrid
                anchors.fill: parent
                cellWidth: Math.max(1, Math.floor((Math.max(0, width - rightMargin)) / 4))
                cellHeight: cellWidth * 0.62 + 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredWallpapers
                reuseItems: true
                cacheBuffer: Math.max(800, cellHeight * 5)
                rightMargin: 12
                ScrollBar.vertical: Menu.MenuScrollBar {}
                WheelHandler {
                  target: null
                  acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                  onWheel: function(ev) {
                    const step = WallThumbs.wheelStep(ev.pixelDelta.y, ev.angleDelta.y, wallpaperGrid.cellHeight)
                    wallpaperGrid.contentY = WallThumbs.clampedContentY(
                      wallpaperGrid.contentY, step, wallpaperGrid.contentHeight, wallpaperGrid.height)
                    ev.accepted = true
                  }
                }

                delegate: Item {
                  required property string modelData
                  width: wallpaperGrid.cellWidth
                  height: wallpaperGrid.cellHeight

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Style.menuRadiusMd
                    clip: true
                    color: wallMa.containsMouse ? Style.m3containerHigh : Style.m3container
                    border.color: Style.m3primary
                    border.width: WallpaperService.currentWallpaper === modelData ? 2 : 0

                    Image {
                      anchors.fill: parent
                      anchors.margins: 1
                      source: WallpaperService.previewSource(modelData)
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      cache: true
                      sourceSize.width: 320
                      sourceSize.height: 192
                      Rectangle {
                        anchors.fill: parent
                        color: Style.m3container
                        visible: parent.status !== Image.Ready
                        Text { anchors.centerIn: parent; text: "󰋩"; color: Style.m3outline; font.pixelSize: 22; font.family: root.uiFont }
                      }
                    }

                    Rectangle {
                      anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                      height: 20
                      color: Qt.rgba(0, 0, 0, 0.6)
                      Text {
                        anchors.centerIn: parent
                        text: modelData.split("/").pop()
                        color: Style.menuInk
                        font.pixelSize: 9
                        font.family: Style.menuSans
                        elide: Text.ElideMiddle
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                      }
                    }

                    MouseArea {
                      id: wallMa
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      acceptedButtons: Qt.LeftButton | Qt.RightButton
                      onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) root.previewPath = modelData
                        else { WallpaperService.setWallpaper(modelData); root.close() }
                      }
                    }
                  }
                }

                Text {
                  anchors.centerIn: parent
                  visible: wallpaperGrid.count === 0
                  text: "No wallpapers found"
                  color: Style.m3outline
                  font.family: Style.menuSans
                  font.pixelSize: 12
                }
              }
            }
          }

          Menu.MenuHintRow {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            fontFamily: Style.menuSans
            hints: "click a window to select · ←/→ browse · ⏎ applies · shift live preview · All lists every wallpaper"
          }
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Style.menuDim
      visible: root.previewPath !== ""
      z: 30
      MouseArea { anchors.fill: parent; onClicked: root.previewPath = "" }
      Image {
        anchors.centerIn: parent
        width: parent.width * 0.86
        height: parent.height * 0.82
        source: root.previewPath !== "" ? "file://" + root.previewPath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: wallpaperPanel.width
        sourceSize.height: wallpaperPanel.height
      }
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 36
        width: applyLbl.width + 32
        height: 38
        radius: Style.menuRadiusFull
        color: applyPreviewMa.containsMouse ? Qt.lighter(Style.m3primary, 1.1) : Style.m3primary
        Row {
          id: applyLbl
          anchors.centerIn: parent
          spacing: 8
          Text { text: "󰄬"; color: Style.m3onPrimary; font.pixelSize: 14; font.family: root.uiFont }
          Text { text: "Apply wallpaper"; color: Style.m3onPrimary; font.pixelSize: 12; font.family: Style.menuSans; font.weight: Font.DemiBold }
        }
        MouseArea {
          id: applyPreviewMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            WallpaperService.setWallpaper(root.previewPath)
            root.previewPath = ""
            root.close()
          }
        }
      }
    }
  }
}
