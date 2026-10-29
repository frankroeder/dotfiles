import QtQuick
import QtQuick.Layouts
import "lookup.js" as Lookup
import "../../"

// Look Up result: term, definition + translation, links. The Super+Shift+D card body (WritingTools) and
// the launcher's `:def <word>` panel. State and the API run live in WritingTools (`tools`).
ColumnLayout {
  id: view
  required property var tools
  property real paneMax: 200
  property bool keyHints: true // the popup's submap keys; the launcher has none
  readonly property var edit: pane.edit
  // Height without the pane: the launcher sizes the pane from what is left.
  readonly property real chrome: head.implicitHeight + links.implicitHeight + 2 * spacing
  // wiki | dict | dictcc | kagi. The host opens it (tools.openLink): the launcher drops this view on close.
  signal linkClicked(string k)
  spacing: 12

  RowLayout {
    id: head
    Layout.fillWidth: true
    spacing: 10
    Rectangle {
      width: 36; height: 36; radius: Style.menuRadiusMd
      color: Style.m3primaryContainer
      Text { anchors.centerIn: parent; text: "󰗚"; color: Style.m3primary; font.family: Style.menuMono; font.pixelSize: 19 }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: !view.tools.hasText ? "Select a word first" : view.tools.entry.term || view.tools.original.trim().replace(/\s+/g, " ")
        color: view.tools.hasText ? Style.m3onSurface : Style.m3onSurfaceVariant
        font.family: Style.menuSans; font.pixelSize: 18; font.weight: Font.DemiBold
      }
      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: [view.tools.entry.pos, view.tools.entry.lang.toUpperCase(), view.tools.appName].filter(s => !!s).join(" · ")
        color: Style.m3onSurfaceVariant
        font.family: Style.menuSans; font.pixelSize: 12
      }
    }
    Text {
      visible: view.tools.busy || view.tools.error !== ""
      font.family: Style.menuSans; font.pixelSize: 12
      color: view.tools.error !== "" ? Style.red : Style.m3onSurfaceVariant
      text: view.tools.error !== "" ? "Failed" : "Looking up…"
      SequentialAnimation on opacity {
        running: view.tools.busy && view.visible
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
      }
    }
  }

  TextPane {
    id: pane
    visible: view.tools.hasText
    Layout.fillWidth: true
    Layout.preferredHeight: wantHeight
    maxHeight: view.paneMax
    rich: view.tools.error === ""
    body: view.tools.error !== "" ? view.tools.error : Lookup.html(view.tools.entry, Style.m3primary.toString()) + (view.tools.busy ? " ▍" : "")
    ink: view.tools.error !== "" ? Style.red : Style.m3onSurface
  }

  RowLayout {
    id: links
    Layout.fillWidth: true
    spacing: 8
    Pill { icon: "󰖬"; label: "Wikipedia"; keyHint: view.keyHints ? "W" : ""; enabled: view.tools.hasText; onClicked: view.linkClicked("wiki") }
    Pill { icon: "󰗚"; label: "Wiktionary"; keyHint: view.keyHints ? "D" : ""; enabled: view.tools.hasText; onClicked: view.linkClicked("dict") }
    Pill { icon: "󰘝"; label: "dict.cc"; keyHint: view.keyHints ? "T" : ""; enabled: view.tools.hasText; onClicked: view.linkClicked("dictcc") }
    Pill { icon: "󰗊"; label: "Kagi"; keyHint: view.keyHints ? "K" : ""; enabled: view.tools.hasText; onClicked: view.linkClicked("kagi") }
  }
}
