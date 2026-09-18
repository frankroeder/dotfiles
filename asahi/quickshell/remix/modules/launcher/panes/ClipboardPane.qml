import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels
import "../launcher_layout.js" as LauncherGeom

// Clipboard pane: cliphist history (M3 caelestia look).
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  id: clipPane
  property var root
  anchors.fill: parent
  property string filter: ""
  readonly property bool missing: root.clipsError === "cliphist-missing"
  readonly property var filtered: {
    const q = clipPane.filter.toLowerCase().trim()
    const list = root.clips || []
    if (!q) return list
    return list.filter(function(c) { return String(c.preview || "").toLowerCase().indexOf(q) >= 0 })
  }
  // Code-ish snippets (braces, shell, paths, markup) read better in mono.
  function looksCode(s) { return /[{}<>;`$\\|]|^\s*[\/#~]|^\s*\w+\(/.test(s || "") }
  // "[[ binary data 3 MiB png 3024x1964 ]]" -> "png · 3024x1964 · 3 MiB"
  function imageHint(s) {
    const m = /binary data (\S+ \S+) (\S+) (\d+x\d+)/.exec(s || "")
    return m ? (m[2] + " · " + m[3] + " · " + m[1]) : (s || "image")
  }

  component Pill: Rectangle {
    property string icon
    property string label
    property color fg: Style.m3onSurface
    property color hoverBg: Style.m3containerHigh
    signal clicked()
    implicitWidth: pillRow.implicitWidth + 24; implicitHeight: 32
    radius: Style.menuRadiusFull
    color: pma.containsMouse ? hoverBg : Style.m3container
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: pillRow; anchors.centerIn: parent; spacing: 7
      Text {
        text: parent.parent.icon; color: parent.parent.fg; font.family: root.uiFont; font.pixelSize: root.fontPx(12)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
        font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  component IconBtn: Rectangle {
    property string icon
    property color tone: Style.m3onSurfaceVariant
    signal clicked()
    width: 30; height: 30; radius: 15
    color: ima.containsMouse ? Style.m3stateHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
    Text { anchors.centerIn: parent; text: parent.icon; color: parent.tone; font.family: root.uiFont; font.pixelSize: root.fontPx(13) }
    MouseArea {
      id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onClicked: (mouse) => { mouse.accepted = true; parent.clicked() }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Filter pill, entry count, wipe.
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32; radius: Style.menuRadiusFull
        color: clipIn.activeFocus ? Style.m3containerHigh : Style.m3container
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
          id: filterGlyph
          anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
          text: "󰍉"; color: clipIn.activeFocus ? Style.m3primary : Style.m3onSurfaceVariant
          font.family: root.uiFont; font.pixelSize: root.fontPx(12)
        }
        TextInput {
          id: clipIn
          anchors.left: filterGlyph.right; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 8; anchors.rightMargin: 12
          color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
          clip: true
          onTextChanged: clipPane.filter = text
          Keys.onEscapePressed: { clipIn.text = ""; if (root.focusLauncherInput) root.focusLauncherInput() }
          Text {
            anchors.fill: parent
            text: "Filter clipboard"; color: Style.m3onSurfaceVariant; font: parent.font
            verticalAlignment: Text.AlignVCenter
            visible: clipIn.text === "" && !clipIn.activeFocus
          }
        }
      }
      Rectangle {
        implicitWidth: countLbl.implicitWidth + 20; implicitHeight: 32; radius: Style.menuRadiusFull
        color: Style.m3secondaryContainer
        Text {
          id: countLbl; anchors.centerIn: parent
          text: clipPane.missing ? "cliphist missing"
            : ((root.clips || []).length + (clipPane.filter ? " · " + clipPane.filtered.length : "") + " entries")
          color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(10); font.weight: Font.Medium
        }
      }
      Pill { icon: "󰩹"; label: "Wipe"; fg: Style.red; hoverBg: Style.panelDangerBg; onClicked: root.wipeClips() }
    }

    // History card.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.menuPanelRadius
      color: Style.m3container

      ListView {
        id: clipList
        anchors.fill: parent
        anchors.margins: 8
        visible: clipPane.filtered.length > 0
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: clipPane.filtered
        ScrollBar.vertical: Menu.MenuScrollBar {}
        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property bool copied: root.copiedClip === String(modelData.id)
          readonly property bool isImage: !!modelData.isImage
          width: clipList.width - 10
          height: isImage ? 64 : 42
          radius: Style.menuRadiusMd
          color: clipMa.containsMouse ? Style.m3stateHover : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            id: clipMa
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function (mouse) {
              if (mouse.button === Qt.RightButton) root.deleteClip(modelData.id)
              else root.copyClip(modelData.id)
            }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 6
            spacing: 10
            // Leading: thumbnail for images, clipboard glyph otherwise.
            ClippingRectangle {
              visible: row.isImage
              Layout.preferredWidth: 72; Layout.preferredHeight: 48
              radius: 8; color: Style.m3containerHigh
              Image {
                anchors.fill: parent
                source: modelData.thumb ? ("file://" + modelData.thumb) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
              Text {
                anchors.centerIn: parent; visible: !modelData.thumb
                text: "󰋩"; color: Style.m3onSurfaceVariant; font.family: root.uiFont; font.pixelSize: root.fontPx(16)
              }
            }
            Text {
              visible: !row.isImage
              text: clipPane.looksCode(modelData.preview) ? "󰅩" : "󰅌"
              color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(14)
            }
            Text {
              Layout.fillWidth: true
              text: row.isImage ? clipPane.imageHint(modelData.preview) : (modelData.preview || "")
              color: Style.m3onSurface
              font.family: !row.isImage && clipPane.looksCode(modelData.preview) ? root.uiFont : root.uiSans
              font.pixelSize: root.fontPx(11)
              elide: Text.ElideRight
              wrapMode: Text.NoWrap
            }
            // Copied chip.
            Rectangle {
              visible: row.copied
              implicitWidth: copiedRow.implicitWidth + 18; implicitHeight: 24
              radius: Style.menuRadiusFull; color: Style.panelSuccessBg
              Row {
                id: copiedRow; anchors.centerIn: parent; spacing: 5
                Text {
                  text: "󰄬"; color: Style.green; font.family: root.uiFont; font.pixelSize: root.fontPx(11)
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "Copied"; color: Style.green; font.family: root.uiSans; font.pixelSize: root.fontPx(9); font.weight: Font.DemiBold
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
            Text {
              visible: !row.copied && !clipMa.containsMouse
              text: "#" + (row.index + 1)
              color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(9)
            }
            IconBtn { visible: clipMa.containsMouse; icon: "󰆏"; onClicked: root.copyClip(row.modelData.id) }
            IconBtn { visible: clipMa.containsMouse; icon: "󰆴"; tone: Style.red; onClicked: root.deleteClip(row.modelData.id) }
          }
        }
      }

      // Empty / missing state.
      ColumnLayout {
        anchors.centerIn: parent
        visible: clipPane.filtered.length === 0
        spacing: 10
        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: 76; height: 76; radius: Style.menuRadiusLg
          color: clipPane.missing ? Style.panelDangerBg : Style.m3primaryContainer
          Text {
            anchors.centerIn: parent; text: clipPane.missing ? "󰅚" : "󰅌"
            color: clipPane.missing ? Style.red : Style.m3primary; font.family: root.uiFont; font.pixelSize: 38
          }
        }
        Text {
          Layout.alignment: Qt.AlignHCenter
          text: clipPane.missing ? "cliphist is not installed" : (clipPane.filter ? "No matching entries" : "Clipboard history is empty")
          color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(14); font.weight: Font.DemiBold
        }
        Text {
          Layout.alignment: Qt.AlignHCenter
          text: clipPane.missing ? "Install cliphist + wl-clipboard to keep a history"
            : (clipPane.filter ? "Try a shorter filter" : "Copy something and it shows up here")
          color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
        }
      }
    }

    Text {
      Layout.fillWidth: true
      text: "Click copies  ·  right-click deletes"
      color: Style.m3onSurfaceVariant
      font.family: root.uiSans; font.pixelSize: root.fontPx(9)
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
