import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../menu" as Menu
import "../../"

Scope {
  id: root

  property string searchText: ""
  property string previewPath: ""
  readonly property string uiFont: "Hack Nerd Font"

  IpcHandler {
    target: "wallpaper"
    function toggle(): void {
      wallpaperPanel.visible = !wallpaperPanel.visible
      if (wallpaperPanel.visible) {
        root.searchText = ""
        root.previewPath = ""
        wallSearchInput.forceActiveFocus()
        if (WallpaperService.wallpapers.length === 0) WallpaperService.rescan()
      }
    }
  }

  property var filteredWallpapers: {
    const q = searchText.toLowerCase()
    if (q === "") return WallpaperService.wallpapers
    return WallpaperService.wallpapers.filter(p => p.split("/").pop().toLowerCase().includes(q))
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

    anchors { top: true; bottom: true; left: true; right: true }

    Menu.MenuBackdrop { reveal: wallpaperPanel.visible ? 1 : 0 }

    MouseArea {
      anchors.fill: parent
      onClicked: wallpaperPanel.visible = false
    }

    Menu.MenuCard {
      id: wallBox
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.12
      width: Math.min(720, parent.width * 0.88)
      height: Math.min(560, parent.height * 0.76)
      cardMargin: 17

      Column {
        id: wallCol
        width: parent.width - 34
        spacing: 12

        Row {
          width: parent.width
          height: 28
          Menu.MenuHeader {
            width: parent.width - 70
            fontFamily: root.uiFont
            title: "ASAHI"
            subtitle: "WALLPAPERS  ·  " + root.filteredWallpapers.length + " IMAGES"
          }
          Rectangle {
            width: 26
            height: 26
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            radius: Style.menuRadius
            color: refreshMa.containsMouse ? Style.menuRowSel : Style.menuControlBg
            border.width: 1
            border.color: Style.menuSep
            Text {
              anchors.centerIn: parent
              text: "󰑐"
              color: refreshMa.containsMouse ? Style.menuSeal : Style.menuInkDeep
              font.pixelSize: 14
              font.family: root.uiFont
            }
            MouseArea {
              id: refreshMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: WallpaperService.rescan()
            }
          }
        }

        Menu.MenuDivider { width: parent.width }

        Item {
          width: parent.width
          height: 36
          Text {
            id: wallSearchGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: wallSearchInput.activeFocus ? Style.menuSeal : Style.menuInkDeep
            font.family: root.uiFont
            font.pixelSize: 16
          }
          TextInput {
            id: wallSearchInput
            anchors.left: wallSearchGlyph.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: text.length > 0 ? Style.menuInk : Style.menuInkDeep
            opacity: text.length > 0 ? 1 : 0.55
            font.family: root.uiFont
            font.pixelSize: 14
            font.letterSpacing: 1
            clip: true
            selectByMouse: true
            onTextChanged: root.searchText = text
            Keys.onEscapePressed: {
              if (root.previewPath !== "") root.previewPath = ""
              else wallpaperPanel.visible = false
            }
            Text {
              anchors.fill: parent
              text: "Search wallpapers…"
              color: Style.menuInkDeep
              font: parent.font
              opacity: 0.5
              visible: !parent.text && !parent.activeFocus
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        Menu.MenuDivider { width: parent.width }

        Item {
          width: parent.width
          height: Math.max(280, wallBox.height - 200)
          clip: true

          GridView {
            id: wallpaperGrid
            anchors.fill: parent
            cellWidth: Math.floor(width / 3)
            cellHeight: cellWidth * 0.62 + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.filteredWallpapers

            delegate: Item {
              required property string modelData
              width: wallpaperGrid.cellWidth
              height: wallpaperGrid.cellHeight

              Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Style.menuRadius
                clip: true
                color: wallMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
                border.color: WallpaperService.currentWallpaper === modelData
                  ? Style.green : Style.menuSep
                border.width: WallpaperService.currentWallpaper === modelData ? 2 : 1

                Image {
                  anchors.fill: parent
                  anchors.margins: 1
                  source: "file://" + modelData
                  fillMode: Image.PreserveAspectCrop
                  sourceSize.width: 200
                  sourceSize.height: 120
                  asynchronous: true
                  Rectangle {
                    anchors.fill: parent
                    color: Style.menuControlBg
                    visible: parent.status !== Image.Ready
                    Text {
                      anchors.centerIn: parent
                      text: "󰋩"
                      color: Style.menuInkDeep
                      font.pixelSize: 22
                      font.family: root.uiFont
                    }
                  }
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: 20
                  color: Qt.rgba(0, 0, 0, 0.6)
                  Text {
                    anchors.centerIn: parent
                    text: modelData.split("/").pop()
                    color: Style.menuInk
                    font.pixelSize: 9
                    font.family: root.uiFont
                    elide: Text.ElideMiddle
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                  }
                }

                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: 6
                  width: 18
                  height: 18
                  radius: 9
                  color: Style.green
                  visible: WallpaperService.currentWallpaper === modelData
                  Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: Style.menuBg
                    font.pixelSize: 11
                    font.bold: true
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
                    else {
                      WallpaperService.setWallpaper(modelData)
                      wallpaperPanel.visible = false
                    }
                  }
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: wallpaperGrid.count === 0
              text: "NO WALLPAPERS FOUND"
              color: Style.menuInkDeep
              font.family: root.uiFont
              font.pixelSize: 11
              font.letterSpacing: 3
              opacity: 0.6
            }
          }
        }

        Menu.MenuDivider { width: parent.width }

        Menu.MenuHintRow {
          width: parent.width
          fontFamily: root.uiFont
          hints: "click apply · right-click preview · " + WallpaperService.backend
        }
      }

      focus: true
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
      }
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 36
        width: applyLbl.width + 32
        height: 38
        radius: Style.menuRadius
        color: applyMa.containsMouse ? Style.menuRowSel : Style.menuControlBg
        border.color: Style.menuSep
        border.width: 1
        Row {
          id: applyLbl
          anchors.centerIn: parent
          spacing: 8
          Text {
            text: "󰄬"
            color: Style.menuSeal
            font.pixelSize: 14
            font.family: root.uiFont
          }
          Text {
            text: "Apply wallpaper"
            color: Style.menuInk
            font.pixelSize: 12
            font.family: root.uiFont
            font.letterSpacing: 1
          }
        }
        MouseArea {
          id: applyMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            WallpaperService.setWallpaper(root.previewPath)
            root.previewPath = ""
          }
        }
      }
    }
  }
}