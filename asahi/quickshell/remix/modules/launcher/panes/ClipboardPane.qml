import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import "../../menu" as Menu
import "../../../"

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

  component IconBtn: Menu.MenuIconBtn { fontScale: root.uiFontScale }

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
          // Swallow keys the field leaves unhandled (arrows at its ends, Return, Tab); otherwise they reach the
          // launcher tiles (Tab: its focus chain) and leave the pane mid-filter. AfterItem: the cursor still moves.
          Keys.priority: Keys.AfterItem
          Keys.onPressed: event => {
            if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Tab, Qt.Key_Backtab]
                .indexOf(event.key) !== -1)
              event.accepted = true
          }
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
      // Wiping the whole history takes two clicks (the first arms it for 3 s), like the notification sheet's trash.
      Menu.MenuPill {
        icon: "󰩹"; label: wipeArm.running ? "Wipe all?" : "Wipe"
        fg: Style.red; bg: wipeArm.running ? Style.panelDangerBg : Style.m3container
        fontScale: root.uiFontScale
        onClicked: {
          if (!wipeArm.running) { wipeArm.restart(); return }
          wipeArm.stop()
          root.wipeClips()
        }
        Timer { id: wipeArm; interval: 3000 }
      }
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
          color: rowHover.hovered ? Style.m3stateHover : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          // Row HoverHandler (not a MouseArea's containsMouse): the IconBtn MouseAreas steal that hover,
          // which hid the buttons while clicks fell through to the row (copy instead of delete).
          HoverHandler { id: rowHover }
          MouseArea {
            anchors.fill: parent
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
              radius: Style.menuRadiusMd; color: Style.m3containerHigh
              Image {
                anchors.fill: parent
                source: modelData.thumb ? ("file://" + modelData.thumb) : ""
                fillMode: Image.PreserveAspectCrop
                // A 72x48 thumb; without sourceSize every full-size screenshot decodes to ~24 MB per row.
                sourceSize.width: 160
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
              textFormat: Text.PlainText
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
              visible: !row.copied && !rowHover.hovered
              text: "#" + (row.index + 1)
              color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(9)
            }
            IconBtn { visible: rowHover.hovered; icon: "󰆏"; onClicked: root.copyClip(row.modelData.id) }
            IconBtn { visible: rowHover.hovered; icon: "󰆴"; tone: Style.red; onClicked: root.deleteClip(row.modelData.id) }
          }
        }
      }

      // Empty / missing state.
      Menu.MenuEmptyState {
        anchors.centerIn: parent
        visible: clipPane.filtered.length === 0
        fontScale: root.uiFontScale
        glyph: clipPane.missing ? "󰅚" : "󰅌"
        tint: clipPane.missing ? Style.red : Style.m3primary
        title: clipPane.missing ? "cliphist is not installed" : (clipPane.filter ? "No matching entries" : "Clipboard history is empty")
        detail: clipPane.missing ? "Install cliphist + wl-clipboard to keep a history"
          : (clipPane.filter ? "Try a shorter filter" : "Copy something and it shows up here")
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
