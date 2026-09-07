import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../"

Item {
  id: root

  property var barHost: null
  property bool calendarOpen: false
  signal calendarToggle()

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

  implicitWidth: solidBar ? flatRow.implicitWidth + 16 : clockRow.implicitWidth + 14
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

  onCalendarOpenChanged: if (root.calendarOpen) root.goToday()

  Row {
    id: flatRow
    visible: root.solidBar
    anchors.centerIn: parent
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
    onClicked: root.calendarToggle()
  }

  PopupWindow {
    id: calPopup
    visible: root.showCalendar
    color: "transparent"
    anchor.item: root
    anchor.edges: Edges.Bottom
    implicitWidth: 336
    implicitHeight: 348

    Rectangle {
      anchors.fill: parent
      color: Style.menuBg
      border.color: Style.menuSep
      border.width: 1
      radius: Style.menuRadius

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

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
          Layout.fillHeight: true
          spacing: 3
          Repeater {
            model: root.weeks
            RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Layout.fillHeight: true
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
                Layout.fillHeight: true
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
                  Layout.fillHeight: true
                  radius: 6
                  readonly property bool isToday: modelData && root.sameDay(new Date(modelData.y, modelData.m, modelData.d), root.today)
                  color: {
                    if (!modelData) return "transparent"
                    if (isToday) return Qt.alpha(Style.menuSeal, 0.22)
                    return dayMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
                  }
                  border.width: isToday ? 1 : 0
                  border.color: Style.menuSeal
                  Text {
                    anchors.centerIn: parent
                    text: modelData ? String(modelData.d) : ""
                    color: parent.isToday ? Style.menuSeal : Style.menuInk
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
      }
    }
  }
}
