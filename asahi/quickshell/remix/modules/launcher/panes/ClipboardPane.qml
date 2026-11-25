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
  // Kind chip ("" = all) on top of the text filter.
  property string kindFilter: ""
  readonly property var filtered: {
    const q = clipPane.filter.toLowerCase().trim()
    let list = root.clips || []
    if (clipPane.kindFilter) list = list.filter(c => clipPane.kind(c) === clipPane.kindFilter)
    if (!q) return list
    return list.filter(function(c) { return String(c.preview || "").toLowerCase().indexOf(q) >= 0 })
  }
  // Entry kinds (surface-dots Clipboard.qml), first match wins: image, colour, link, path, code, text.
  readonly property var kindDefs: [["text", "Text", "󰅌"], ["link", "Links", "󰖟"], ["code", "Code", "󰅩"],
    ["path", "Paths", "󰉋"], ["colour", "Colours", "󰏘"], ["image", "Images", "󰋩"]]
  function kind(c) {
    if (c.isImage) return "image"
    const s = String(c.preview || "").trim()
    if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s) || /^(rgba?|hsla?)\([^)]*\)$/i.test(s)) return "colour"
    if (/^(https?|ftp):\/\/\S+$/i.test(s)) return "link"
    if (/^(~|\.\.?)?\/[\w.\-~@+%\/ ,\[\]]+$/.test(s)) return "path"
    if (clipPane.looksCode(s)) return "code"
    return "text"
  }
  function glyph(k) { return (clipPane.kindDefs.find(d => d[0] === k) || ["", "", "󰅌"])[2] }
  // CSS colour → Qt: #rrggbbaa is #aarrggbb there; rgb()/hsl() strings are not parsed by Qt at all.
  function swatch(s) {
    s = String(s || "").trim()
    if (/^#[0-9a-f]{8}$/i.test(s)) return "#" + s.substring(7) + s.substring(1, 7)
    const m = /^(rgb|hsl)a?\(([^)]*)\)$/i.exec(s)
    if (!m) return s
    const v = m[2].split(/[\s,\/]+/).filter(x => x !== "").map(x => parseFloat(x) / (x.endsWith("%") ? 100 : 1))
    const a = v.length > 3 ? v[3] : 1
    return m[1].toLowerCase() === "rgb" ? Qt.rgba(v[0] / 255, v[1] / 255, v[2] / 255, a) : Qt.hsla(v[0] / 360, v[1], v[2], a)
  }
  readonly property var kindCounts: {
    const n = {}
    for (const c of (root.clips || [])) { const k = clipPane.kind(c); n[k] = (n[k] || 0) + 1 }
    return n
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
        implicitHeight: root.fieldHSm; radius: Style.menuRadiusFull
        color: clipIn.activeFocus ? Style.m3containerHigh : Style.m3container
        border.width: clipIn.activeFocus ? Style.focusRingWidth : 0; border.color: Style.focusRing
        Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
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

    // Kind chips: All + every kind present, with counts (the total lives in "All").
    Flow {
      Layout.fillWidth: true
      spacing: 6
      visible: !clipPane.missing && (root.clips || []).length > 0
      Repeater {
        model: [["", "All", ""]].concat(clipPane.kindDefs.filter(d => (clipPane.kindCounts[d[0]] || 0) > 0))
        Menu.MenuChip {
          required property var modelData
          readonly property bool on: clipPane.kindFilter === modelData[0]
          icon: modelData[2]
          label: modelData[1] + "  " + (modelData[0] ? clipPane.kindCounts[modelData[0]]
            : (root.clips || []).length + (clipPane.filter ? " · " + clipPane.filtered.length : ""))
          bg: on ? Style.m3primaryContainer : Style.m3container
          fg: on ? Style.m3primary : Style.m3onSurfaceVariant
          clickable: true
          fontScale: root.uiFontScale
          onClicked: clipPane.kindFilter = on ? "" : modelData[0]
        }
      }
    }

    // History card.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.menuPaneRadius
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
        ScrollBar.vertical: Menu.MenuScrollBar { id: clipScroll }
        Menu.MenuEdgeFade { parent: clipList; surface: Style.m3container; atTop: true; gutter: clipScroll.width }
        Menu.MenuEdgeFade { parent: clipList; surface: Style.m3container; gutter: clipScroll.width }
        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property bool copied: root.copiedClip === String(modelData.id)
          readonly property bool isImage: !!modelData.isImage
          readonly property string kind: clipPane.kind(modelData)
          readonly property bool hasThumb: isImage && !!modelData.thumb
          width: clipList.width - 10
          height: hasThumb ? root.fontPx(48) : root.listRowH
          radius: Style.menuRowRadius
          color: rowHover.hovered ? Style.m3stateHover : "transparent"
          Behavior on color { ColorAnimation { duration: Style.menuStateMs } }

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
            // Leading: an image's thumbnail (his pick: images first), else one slot for the kind glyph (a colour shows
            // itself; an image without a thumbnail gets the image glyph), so text labels share one x.
            ClippingRectangle {
              visible: row.hasThumb
              Layout.preferredWidth: root.fontPx(54); Layout.preferredHeight: root.fontPx(36)
              radius: Style.menuRadiusSm; color: Style.m3containerHigh   // inside an 8 px row
              Image {
                anchors.fill: parent
                source: modelData.thumb ? ("file://" + modelData.thumb) : ""
                fillMode: Image.PreserveAspectCrop
                // A 72x48 thumb; without sourceSize every full-size screenshot decodes to ~24 MB per row.
                sourceSize.width: 160
                asynchronous: true
              }
            }
            Text {
              visible: row.kind !== "colour" && !row.hasThumb
              Layout.preferredWidth: root.listSlot
              horizontalAlignment: Text.AlignHCenter
              text: clipPane.glyph(row.kind)
              color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(14)
            }
            Rectangle {   // a colour value shows itself
              visible: row.kind === "colour"
              Layout.preferredWidth: root.fontPx(14); Layout.preferredHeight: root.fontPx(14)
              Layout.leftMargin: (root.listSlot - width) / 2; Layout.rightMargin: (root.listSlot - width) / 2
              radius: width / 2
              color: row.kind === "colour" ? clipPane.swatch(modelData.preview) : "transparent"
              border.width: 1; border.color: Style.m3outlineVariant
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
              implicitWidth: copiedRow.implicitWidth + 18; implicitHeight: root.fontPx(18)
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
              Layout.minimumWidth: root.fontPx(20); horizontalAlignment: Text.AlignRight; font.features: Style.fontTabular
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
