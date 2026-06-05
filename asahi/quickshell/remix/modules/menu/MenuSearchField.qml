import QtQuick
import QtQuick.Controls
import "../../"

Item {
  id: root
  required property var input
  property string glyph: "󰍉"
  property string placeholder: "Type to search..."
  property real fontScale: 1.0
  property string fontFamily: "Hack Nerd Font"

  width: parent ? parent.width : 0
  height: 36

  Text {
    id: prompt
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.glyph
    color: root.input.activeFocus ? Style.menuSeal : Style.menuInkDeep
    font.family: root.fontFamily
    font.pixelSize: 16 * root.fontScale

    Behavior on color { ColorAnimation { duration: 120 } }
  }

  TextInput {
    id: field
    anchors.left: prompt.right
    anchors.leftMargin: 10
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    color: root.input.text.length > 0 ? Style.menuInk : Style.menuInkDeep
    opacity: root.input.text.length > 0 ? 1 : 0.55
    font.family: root.fontFamily
    font.pixelSize: 14 * root.fontScale
    font.letterSpacing: 1
    clip: true
    focus: true
    text: root.input.text
    onTextChanged: root.input.text = text

    Text {
      anchors.fill: parent
      text: root.placeholder
      color: Style.menuInkDeep
      font: parent.font
      opacity: 0.5
      visible: parent.text.length === 0 && !parent.activeFocus
      verticalAlignment: Text.AlignVCenter
    }
  }

  Rectangle {
    width: 2
    height: 16 * root.fontScale
    color: Style.menuSeal
    anchors.verticalCenter: parent.verticalCenter
    x: field.x + field.contentWidth + 2
    visible: root.input.activeFocus
    SequentialAnimation on opacity {
      running: root.input.activeFocus
      loops: Animation.Infinite
      NumberAnimation { from: 1; to: 0.25; duration: 600; easing.type: Easing.InOutSine }
      NumberAnimation { from: 0.25; to: 1; duration: 600; easing.type: Easing.InOutSine }
    }
  }
}
