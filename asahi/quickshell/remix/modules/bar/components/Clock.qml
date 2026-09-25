import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../../"
import "../life_span.js" as Life

Item {
  id: root

  property var barHost: null
  property bool calendarOpen: false
  signal calendarToggle()
  property bool clickOpened: false
  property bool yearFocused: false

  readonly property bool solidBar: barHost !== null && barHost !== undefined
  readonly property bool showCalendar: {
    if (!root.calendarOpen) return false
    const mon = Hyprland.focusedMonitor
    const scr = barHost ? barHost.barScreen : null
    if (!mon || !scr) return true
    return mon.name === scr.name
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  readonly property string timeLine: Qt.formatDateTime(clock.date, "HH:mm")
  readonly property string dateLine: Qt.formatDateTime(clock.date, "ddd dd MMM")

  property date viewMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
  property date today: new Date()
  property var birthYear: null
  property bool birthLoaded: false
  property bool birthFieldReady: false
  property bool birthFilePresent: false
  readonly property string birthPath: Life.birthStorePath(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"))
  readonly property var life: Life.lifeSpan(root.birthYear, root.today)

  function lifeColor(cls) {
    if (cls === "now") return Style.menuSeal
    if (cls === "lived") return Qt.alpha(Style.menuInk, 0.72)
    return Qt.alpha(Style.menuInk, 0.14)
  }

  function applyBirthText(text, filePresent) {
    root.birthLoaded = true
    if (filePresent === true || filePresent === false) root.birthFilePresent = filePresent
    root.birthYear = Life.resolveBirthYear(text, Quickshell.env("BIRTH_YEAR"), root.birthFilePresent)
    root.syncBirthField()
  }

  // FileView can finish before the popup builds the field. Sync once the field exists.
  function syncBirthField() {
    if (!root.birthFieldReady) return
    const shown = root.birthYear == null ? "" : String(root.birthYear)
    if (birthField.text !== shown) birthField.text = shown
  }

  function commitBirth(raw) {
    if (!root.birthLoaded) return
    const text = String(raw == null ? "" : raw).trim()
    const year = Life.decodeBirthYear(text)
    if (text !== "" && year == null) return
    root.birthFilePresent = true
    root.birthYear = year
    const encoded = Life.encodeBirthYear(year)
    if (birthFile.text() !== encoded) birthFile.setText(encoded)
  }

  implicitWidth: solidBar ? flatRow.implicitWidth + 12 : clockRow.implicitWidth + 14
  implicitHeight: solidBar ? Style.barHeight : 26

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }

  function monthLabel() {
    return Qt.formatDate(root.viewMonth, "MMMM yyyy")
  }

  function shiftMonth(delta) {
    root.viewMonth = new Date(root.viewMonth.getFullYear(), root.viewMonth.getMonth() + delta, 1)
  }

  function goToday() {
    const now = new Date()
    root.today = now
    root.viewMonth = new Date(now.getFullYear(), now.getMonth(), 1)
  }

  // ISO-8601 week (Monday-first). Thursday decides the year.
  function isoWeek(y, m, d) {
    const utc = new Date(Date.UTC(y, m, d))
    const dayNum = utc.getUTCDay() || 7
    utc.setUTCDate(utc.getUTCDate() + 4 - dayNum)
    const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1))
    return Math.ceil((((utc.getTime() - yearStart.getTime()) / 86400000) + 1) / 7)
  }

  readonly property var weeks: {
    const y = root.viewMonth.getFullYear()
    const m = root.viewMonth.getMonth()
    const first = new Date(y, m, 1)
    const last = new Date(y, m + 1, 0).getDate()
    let start = first.getDay() - 1
    if (start < 0) start = 6
    const out = []
    let day = 1
    while (day <= last) {
      const days = []
      if (out.length === 0) {
        for (let i = 0; i < start; i++) days.push(null)
      }
      while (days.length < 7 && day <= last) {
        days.push({ y: y, m: m, d: day })
        day++
      }
      while (days.length < 7) days.push(null)
      let wday = days[0]
      for (let i = 0; i < days.length; i++) {
        if (days[i]) { wday = days[i]; break }
      }
      out.push({ w: wday ? root.isoWeek(wday.y, wday.m, wday.d) : 0, days: days })
    }
    return out
  }

  onCalendarOpenChanged: if (root.calendarOpen) {
    root.goToday()
    birthFile.reload()
  } else root.clickOpened = false

  Process {
    id: ensureBirthDir
    command: ["mkdir", "-p", root.birthPath.slice(0, root.birthPath.lastIndexOf("/"))]
    running: true
  }

  FileView {
    id: birthFile
    path: root.birthPath
    watchChanges: true
    blockLoading: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyBirthText(birthFile.text(), true)
    onTextChanged: if (root) root.applyBirthText(birthFile.text())
    onLoadFailed: root.applyBirthText("", false)
  }
  // Flush right: the clock is the last item, so its outer pad would double
  // the bar edge margin (left edge sits at barEdgeMargin, right drifted to ~2×).
  Row {
    id: flatRow
    visible: root.solidBar
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    Text {
      text: root.dateLine
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: Style.barStripMuted
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: root.timeLine
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: barHost ? barHost.barForeground : Style.barStripText
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Rectangle {
    visible: !root.solidBar
    anchors.fill: parent
    color: Style.barBg
    radius: Style.radius
    border.width: 1
    border.color: Style.barBorder

    RowLayout {
      id: clockRow
      anchors.centerIn: parent
      spacing: 6

      Text {
        text: root.dateLine
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontBody
        color: Style.cyan
      }
      Text {
        text: root.timeLine
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontBody
        color: Style.cyan
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.clickOpened = true
      root.calendarToggle()
    }
  }

  PopupWindow {
    id: calPopup
    visible: root.showCalendar
    color: "transparent"
    // Right edge on the clock's (= bar edge margin), growing leftwards.
    anchor.item: root
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    implicitWidth: 340
    implicitHeight: calCol.implicitHeight + 24

    Shortcut {
      enabled: root.showCalendar
      sequences: ["Escape"]
      onActivated: root.calendarToggle()
    }

    // Click opens grab only once the year field is focused: grabbing on open
    // makes Hyprland treat the opening click as outside and the popup vanishes.
    // Keybind / IPC opens grab at once so Esc closes the calendar, not the app.
    HyprlandFocusGrab {
      id: calendarKeys
      windows: [calPopup]
      active: root.showCalendar && (!root.clickOpened || root.yearFocused)
      onCleared: if (!root.clickOpened && root.calendarOpen) root.calendarToggle()
    }

    Rectangle {
      anchors.fill: parent
      color: Style.menuBg
      border.color: Style.menuSep
      border.width: 1
      radius: Style.menuRadiusLg

      ColumnLayout {
        id: calCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: "󰸗"
            color: Style.menuSeal
            font.family: Style.fontFamily
            font.pixelSize: 16
          }
          Text {
            Layout.fillWidth: true
            text: root.monthLabel()
            color: Style.menuInk
            font.family: Style.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
          }
          Rectangle {
            width: 26; height: 26; radius: 8
            color: prevMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
            border.color: Style.menuSep; border.width: 1
            Text { anchors.centerIn: parent; text: "‹"; color: Style.menuInk; font.pixelSize: 15 }
            MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shiftMonth(-1) }
          }
          Rectangle {
            width: 50; height: 26; radius: 8
            color: todayMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
            border.color: Style.menuSep; border.width: 1
            Text { anchors.centerIn: parent; text: "today"; color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 10 }
            MouseArea { id: todayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goToday() }
          }
          Rectangle {
            width: 26; height: 26; radius: 8
            color: nextMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
            border.color: Style.menuSep; border.width: 1
            Text { anchors.centerIn: parent; text: "›"; color: Style.menuInk; font.pixelSize: 15 }
            MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shiftMonth(1) }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 3
          Text {
            Layout.preferredWidth: 18
            horizontalAlignment: Text.AlignHCenter
            text: "W"
            color: Style.menuInkDeep
            font.family: Style.fontFamily
            font.pixelSize: 8
            opacity: 0.7
          }
          Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text {
              required property string modelData
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: modelData
              color: Style.menuInkDeep
              font.family: Style.fontFamily
              font.pixelSize: 10
              font.letterSpacing: 0.6
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 3
          Repeater {
            model: root.weeks
            RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredHeight: 26
              spacing: 3
              readonly property bool weekIsCurrent: {
                const days = modelData.days || []
                for (let i = 0; i < days.length; i++) {
                  const c = days[i]
                  if (c && root.sameDay(new Date(c.y, c.m, c.d), root.today)) return true
                }
                return false
              }
              Text {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 26
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: modelData.w ? String(modelData.w) : ""
                color: parent.weekIsCurrent ? Style.menuSeal : Style.menuInkDeep
                font.family: Style.fontFamily
                font.pixelSize: 8
                opacity: 0.85
              }
              Repeater {
                model: modelData.days
                Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  Layout.preferredHeight: 26
                  radius: 6
                  readonly property bool isToday: modelData && root.sameDay(new Date(modelData.y, modelData.m, modelData.d), root.today)
                  color: {
                    if (!modelData) return "transparent"
                    if (isToday) return Style.menuSeal
                    return dayMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
                  }
                  border.width: 0
                  Text {
                    anchors.centerIn: parent
                    text: modelData ? String(modelData.d) : ""
                    // Filled "today" (M3 date picker): a 22% wash read as disabled on grey accents.
                    color: parent.isToday ? Style.menuOnAccent : Style.menuInk
                    font.family: Style.fontFamily
                    font.pixelSize: 12
                    font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                  }
                  MouseArea {
                    id: dayMa
                    anchors.fill: parent
                    hoverEnabled: !!modelData
                    enabled: !!modelData
                  }
                }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          text: Qt.formatDate(root.today, "dddd, d MMMM yyyy")
          color: Style.menuInkDeep
          font.family: Style.fontFamily
          font.pixelSize: 11
          horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Style.menuSep
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: "Life"
            color: Style.menuInkDeep
            font.family: Style.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 0.6
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            Layout.preferredWidth: 72
            Layout.preferredHeight: 26
            radius: 8
            color: birthField.activeFocus ? Style.menuRowHi : Style.menuControlBg
            border.color: birthField.activeFocus ? Style.menuSeal : Style.menuSep
            border.width: 1
            TextInput {
              id: birthField
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              verticalAlignment: TextInput.AlignVCenter
              horizontalAlignment: Text.AlignHCenter
              color: Style.menuInk
              font.family: Style.fontFamily
              font.pixelSize: 12
              clip: true
              selectByMouse: true
              maximumLength: 4
              validator: RegularExpressionValidator { regularExpression: /[0-9]{0,4}/ }
              Component.onCompleted: {
                root.birthFieldReady = true
                root.syncBirthField()
              }
              onActiveFocusChanged: root.yearFocused = activeFocus
              onTextEdited: if (text.length === 4) root.commitBirth(text)
              // Return/Enter and focus loss; a partial year snaps back to the saved one.
              onEditingFinished: {
                root.commitBirth(text)
                root.syncBirthField()
              }
              Text {
                enabled: false
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "year"
                color: Style.menuInkDeep
                font: parent.font
                opacity: 0.7
                visible: parent.text.length === 0 && !parent.activeFocus
              }
            }
          }
        }

        RowLayout {
          visible: root.life.set
          Layout.fillWidth: true
          Text {
            text: root.life.yearsLeft + " years left"
            color: Style.menuInk
            font.family: Style.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.life.percentLeft + "% left"
            color: Style.menuSeal
            font.family: Style.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
          }
        }

        Text {
          visible: !root.life.set
          Layout.fillWidth: true
          text: "Enter a birth year"
          color: Style.menuInkDeep
          font.family: Style.fontFamily
          font.pixelSize: 11
          horizontalAlignment: Text.AlignHCenter
        }

        Grid {
          visible: root.life.set
          Layout.alignment: Qt.AlignHCenter
          columns: 18
          columnSpacing: 5
          rowSpacing: 5
          Repeater {
            model: root.life.set ? root.life.cells : []
            Rectangle {
              required property string modelData
              width: 6
              height: 6
              radius: 3
              color: root.lifeColor(modelData)
            }
          }
        }
      }
    }
  }
}
