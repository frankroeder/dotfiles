import QtQuick
import QtQuick.Controls
import "../menu" as Menu
import "../../"

// Scrollable read-only rich text (diff colours), selectable for copying.
Rectangle {
  id: pane
  property alias edit: paneEdit
  property string body: ""
  property bool rich: false
  property color ink: Style.m3onSurface
  property real maxHeight: 200
  readonly property real wantHeight: Math.min(paneEdit.implicitHeight + 20, maxHeight)
  radius: Style.menuRadiusMd
  color: Style.menuCardBg
  clip: true
  Flickable {
    id: flick
    anchors.fill: parent
    anchors.margins: 10
    contentHeight: paneEdit.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    TextEdit {
      id: paneEdit
      width: flick.width - 10 // fixed gutter: a bar-dependent width loops through contentHeight
      readOnly: true
      persistentSelection: true // the card never has keyboard focus
      wrapMode: TextEdit.Wrap
      textFormat: pane.rich ? TextEdit.RichText : TextEdit.PlainText
      text: pane.body
      color: pane.ink
      selectionColor: Style.menuSelFill
      selectedTextColor: Style.m3onSurface
      font.family: Style.menuSans
      font.pixelSize: 14
      // Own drag-select instead of selectByMouse: Qt's mouse selection claims the primary
      // selection, and GTK apps then drop the very selection Replace pastes over.
      MouseArea {
        property int anchor: 0
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        preventStealing: true
        onPressed: mouse => { anchor = paneEdit.positionAt(mouse.x, mouse.y); paneEdit.select(anchor, anchor) }
        onPositionChanged: mouse => paneEdit.select(anchor, paneEdit.positionAt(mouse.x, mouse.y))
        onDoubleClicked: mouse => { paneEdit.cursorPosition = paneEdit.positionAt(mouse.x, mouse.y); paneEdit.selectWord() }
      }
    }
    Menu.MenuScrollBar { id: bar; parent: flick; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }
    ScrollBar.vertical: bar
  }
}
