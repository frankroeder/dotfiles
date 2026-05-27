import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../wallpaper" as Wallpaper
import "../../"

Scope {
  id: root

  property var theme: Wallpaper.DefaultTheme
  property bool shouldShow: false
  property string query: ""
  property int selectedIndex: 0
  property var launcherScreen: null
  property int resultCount: 0
  property int deVersion: 0

  readonly property string headerText: {
    const q = root.query.trim()
    if (q.startsWith("=")) return "Calculator"
    if (q.startsWith("!")) return "Web Search"
    if (q.startsWith("@")) return "Documentation"
    return "Applications"
  }

  readonly property string resultText: {
    const c = root.resultCount
    const s = c !== 1 ? "s" : ""
    const qq = root.query.trim()
    if (qq.startsWith("=") || qq.startsWith("!") || qq.startsWith("@")) return c + " result" + s
    return c + " application" + s
  }

  onResultCountChanged: {
    const max = Math.max(0, root.resultCount - 1)
    if (resultsList && resultsList.currentIndex > max && max >= 0) {
      resultsList.currentIndex = max
    }
  }

  function launchCurrent() {
    let entry = null
    if (resultsList && resultsList.currentItem && resultsList.currentItem.modelData) {
      entry = resultsList.currentItem.modelData
    } else if (filteredApps && filteredApps.values && resultsList.currentIndex < filteredApps.values.length) {
      entry = filteredApps.values[resultsList.currentIndex]
    }
    if (entry) root.launchApp(entry)
  }

  function openLauncher() {
    const mon = Hyprland.focusedMonitor
    launcherScreen = mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
    shouldShow = true
    searchInput.text = ""
    if (resultsList) resultsList.currentIndex = 0
    Qt.callLater(() => { if (searchInput) searchInput.forceActiveFocus() })
  }

  function closeLauncher() {
    shouldShow = false
  }

  function launchApp(entry) {
    if (!entry) { shouldShow = false; return }
    if (entry.special === "calc") {
      const res = entry.result || ""
      if (res) Quickshell.execDetached(["bash", "-c", "echo -n '" + res.replace(/'/g, "'\\''") + "' | wl-copy"])
    } else if ((entry.special === "web" || entry.special === "doc") && entry.url) {
      let u = entry.url
      if (u.includes("%TERM%")) u = u.replace("%TERM%", "")
      u = u.replace(/\?q=$/, "").replace(/\?s=$/, "").replace(/&text=$/, "").replace(/search\?q=$/, "")
      Quickshell.execDetached(["xdg-open", u])
    } else if (entry.execute) {
      entry.execute()
    }
    shouldShow = false
  }

  // websearch: @ uses engines[] from json (fuzzy lists + prefix direct). ! passes the literal text (e.g. "!yt hello") to Kagi via defaultSearchUrl.
  property var webEngines: [
    { name: "Kagi", prefix: "kagi", url: "https://kagi.com/search?q=%TERM%", icon: "󰖟" },
    { name: "Jax Documentation", prefix: "jaxdoc", url: "https://docs.jax.dev/en/latest/search.html?q=%TERM%", icon: "󰈙" },
    { name: "Flax Documentation", prefix: "flaxdoc", url: "https://flax.readthedocs.io/en/stable/search.html?q=%TERM%", icon: "󰈙" },
    { name: "dict.cc", prefix: "dcc", url: "https://www.dict.cc/?s=%TERM%", icon: "󰗊" },
    { name: "NumPy Documentation", prefix: "npdoc", url: "https://numpy.org/doc/stable/search.html?q=%TERM%", icon: "󰈙" },
    { name: "Kagi Translate", prefix: "kt", url: "https://translate.kagi.com/?from=auto&to=en_us&text=%TERM%", icon: "󰗊" },
    { name: "PyTorch Documentation", prefix: "ptdoc", url: "https://docs.pytorch.org/docs/stable/search.html?q=%TERM%", icon: "󰈙" }
  ]
  property string defaultSearchUrl: "https://kagi.com/search?q=%s"

  function loadWebsearchConfig() {
    var xhr = new XMLHttpRequest()
    var url = Qt.resolvedUrl("./websearch.json")
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200 || xhr.status === 0) {
          try {
            var data = JSON.parse(xhr.responseText)
            if (data.engines && data.engines.length > 0) webEngines = data.engines
            if (data.defaultSearchUrl) defaultSearchUrl = data.defaultSearchUrl
          } catch (e) {
            console.warn("websearch.json parse failed")
          }
        }
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  Component.onCompleted: loadWebsearchConfig()

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() { root.deVersion++ }
  }

  function calculate(expr) {
    expr = (expr || "").trim()
    if (!expr) return null
    try {
      let e = expr.replace(/π/g, "Math.PI").replace(/pi/gi, "Math.PI")
      e = e.replace(/e\b/g, "Math.E")
      e = e.replace(/sqrt\(/gi, "Math.sqrt(")
      e = e.replace(/\^/g, "**")
      const val = eval(e)
      if (typeof val === "number" && isFinite(val)) {
        return Number.isInteger(val) ? val.toString() : parseFloat(val.toFixed(8)).toString()
      }
      return null
    } catch (_) { return null }
  }

  function getSpecialResults(qq) {
    const q = (qq || "").trim()
    if (!q) return null
    if (q.startsWith("=")) {
      const res = calculate(q.substring(1))
      if (res !== null) {
        return [{ id: "calc-" + res, name: "= " + res, comment: "Calculator — Enter to copy", icon: "󰃀", special: "calc", result: res }]
      }
      return null
    }
    if (q.startsWith("!")) {
      // Literal pass-through to Kagi (defaultSearchUrl). Whatever you type after ! is sent as the query string.
      const t = q.trim()
      if (t) {
        const tpl = root.defaultSearchUrl
        return [{
          id: "web",
          name: t,
          comment: "Kagi — Enter to search",
          icon: "󰖟",
          special: "web",
          url: tpl.replace("%s", encodeURIComponent(t))
        }]
      }
      return null
    }
    if (q.startsWith("@")) {
      const after = q.substring(1).trim()
      const la = after.toLowerCase()

      const engines = root.webEngines.length > 0 ? root.webEngines : [{
        name: "Kagi", prefix: "kagi", url: "https://kagi.com/search?q=%TERM%", icon: "󰖟"
      }]

      // tiny subsequence fuzzy (for suggestion lists when typing partial @)
      const fuzzy = (hay, ned) => {
        if (!ned) return true
        hay = hay.toLowerCase(); ned = ned.toLowerCase()
        let i = 0
        for (const c of hay) { if (c === ned[i]) i++; if (i === ned.length) return true }
        return false
      }

      // exact prefix match for direct search (e.g. @ptdoc hello → PyTorch docs with the term)
      for (const e of engines) {
        const p = e.prefix
        if (la === p || la.startsWith(p + " ")) {
          let raw = after.substring(p.length).trim()
          const term = raw.replace(/^["'\s]+|["'\s]+$/g, "")
          let u = e.url
          if (term) u = u.replace("%TERM%", encodeURIComponent(term))
          else u = u.replace("%TERM%", "").replace(/\?q=$/, "").replace(/\?s=$/, "").replace(/&text=$/, "").replace(/search\?q=$/, "")
          return [{
            id: "doc-" + p,
            name: e.name + (term ? " — " + term : ""),
            comment: "Docs search — Enter to open",
            icon: e.icon,
            special: "doc",
            url: u
          }]
        }
      }

      // fuzzy list (matches prefix or name via subsequence) for @partial
      const f = engines.filter(e => fuzzy(e.prefix, la) || fuzzy(e.name, la) || la === "")
      if (f.length > 0) {
        return f.map(e => ({
          id: "doclist-" + e.prefix,
          name: e.name,
          comment: "@" + e.prefix + " — select to search",
          icon: e.icon,
          special: "doc",
          url: e.url.replace("%TERM%", "")
        }))
      }

      // fallback
      const t = after || ""
      const u = root.defaultSearchUrl.replace("%s", encodeURIComponent(t))
      return [{ id: "docdef", name: "Kagi — " + t, comment: "Enter to search", icon: "󰖟", special: "doc", url: u }]
    }
    return null
  }

  ScriptModel {
    id: filteredApps
    objectProp: "id"
    values: {
      root.deVersion
      const specials = root.getSpecialResults(root.query)
      if (specials && specials.length > 0) return specials
      let all = [...DesktopEntries.applications.values]
      all = all.filter(d => !d.noDisplay)
      const q = root.query.trim().toLowerCase()
      if (q === "") {
        return all.sort((a, b) => (a.name || "").localeCompare(b.name || ""))
      }
      const filtered = all.filter(d =>
        (d.name && d.name.toLowerCase().includes(q)) ||
        (d.genericName && d.genericName.toLowerCase().includes(q)) ||
        (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q))) ||
        (d.categories && d.categories.some(c => c.toLowerCase().includes(q)))
      )
      return filtered.sort((a, b) => {
        const an = (a.name || "").toLowerCase()
        const bn = (b.name || "").toLowerCase()
        const aStarts = an.startsWith(q)
        const bStarts = bn.startsWith(q)
        if (aStarts && !bStarts) return -1
        if (!aStarts && bStarts) return 1
        return an.localeCompare(bn)
      })
    }
  }

  PanelWindow {
    id: launcherPanel
    visible: root.shouldShow
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-launcher"
    exclusionMode: ExclusionMode.Ignore

    screen: root.launcherScreen

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Dark overlay backdrop
    MouseArea {
      anchors.fill: parent
      onClicked: root.shouldShow = false

      Rectangle {
        anchors.fill: parent
        color: root.theme.bgOverlay
      }
    }

    // Centered launcher box
    Rectangle {
      id: launcherBox
      anchors.centerIn: parent
      width: 580
      height: 480
      radius: 16
      color: root.theme.bgBase
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        Text {
          text: root.headerText
          color: root.theme.accentPrimary
          font.pixelSize: 14
          font.family: "Hack Nerd Font"
          font.bold: true
        }

        // Search bar
        Rectangle {
          Layout.fillWidth: true
          height: 44
          radius: 10
          color: root.theme.bgSurface
          border.color: searchInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
          border.width: 1

          Behavior on border.color {
            ColorAnimation { duration: 150 }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Text {
              text: "󰍉"
              color: root.theme.textMuted
              font.pixelSize: 18
              font.family: "Hack Nerd Font"
              Layout.alignment: Qt.AlignVCenter
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              color: root.theme.textPrimary
              font.pixelSize: 15
              font.family: "Hack Nerd Font"
              clip: true
              focus: true
              Accessible.role: Accessible.EditableText
              Accessible.name: "Search applications"

              Text {
                anchors.fill: parent
                text: "Type to search..."
                color: root.theme.textMuted
                font: parent.font
                visible: !parent.text && !parent.activeFocus
                verticalAlignment: Text.AlignVCenter
              }

              onTextChanged: {
                root.query = text
                if (resultsList) resultsList.currentIndex = 0
              }

              Keys.onEscapePressed: root.shouldShow = false
              Keys.onReturnPressed: root.launchCurrent()
              Keys.onEnterPressed: root.launchCurrent()

              Keys.onPressed: event => {
                const max = Math.max(0, root.resultCount - 1)
                if (event.key === Qt.Key_Down) {
                  event.accepted = true
                  resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, max)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                } else if (event.key === Qt.Key_Up) {
                  event.accepted = true
                  resultsList.currentIndex = Math.max(resultsList.currentIndex - 1, 0)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                } else if (event.key === Qt.Key_Tab) {
                  event.accepted = true
                  resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, max)
                  resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                }
              }
            }
          }
        }

        // Results count
        Text {
          text: root.resultText
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: "Hack Nerd Font"
        }

        // App list
        ListView {
          id: resultsList
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: filteredApps
          clip: true
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: 0
          highlightMoveDuration: 150
          highlightMoveVelocity: -1

          onCountChanged: root.resultCount = count
          onCurrentIndexChanged: if (currentIndex >= 0) root.selectedIndex = currentIndex

          highlight: Rectangle {
            radius: 8
            color: root.theme.bgSelected

            Rectangle {
              width: 3
              height: 24
              radius: 2
              color: root.theme.accentPrimary
              anchors.left: parent.left
              anchors.leftMargin: 2
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          delegate: Rectangle {
            id: delegateRoot
            required property var modelData
            required property int index

            Accessible.role: Accessible.Button
            Accessible.name: (modelData.name ?? "Application") + (modelData.genericName ? " - " + modelData.genericName : "")

            width: resultsList.width
            height: 44
            radius: 8
            color: hoverArea.containsMouse && resultsList.currentIndex !== index ? root.theme.bgHover : "transparent"

            Behavior on color {
              ColorAnimation { duration: 100 }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              // App icon
              Item {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter

                IconImage {
                  anchors.fill: parent
                  source: Quickshell.iconPath(delegateRoot.modelData.icon ?? "", true)
                  visible: (delegateRoot.modelData.icon ?? "") !== ""
                }

                // Fallback letter icon
                Text {
                  anchors.centerIn: parent
                  text: (delegateRoot.modelData.name ?? "?").charAt(0).toUpperCase()
                  color: root.theme.accentPrimary
                  font.pixelSize: 16
                  font.family: "Hack Nerd Font"
                  font.bold: true
                  visible: (delegateRoot.modelData.icon ?? "") === ""
                }
              }

              // App info
              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                  text: delegateRoot.modelData.name ?? ""
                  color: resultsList.currentIndex === delegateRoot.index ? root.theme.textPrimary : root.theme.textSecondary
                  font.pixelSize: 13
                  font.family: "Hack Nerd Font"
                  font.bold: resultsList.currentIndex === delegateRoot.index
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: delegateRoot.modelData.genericName ?? delegateRoot.modelData.comment ?? ""
                  color: root.theme.textMuted
                  font.pixelSize: 11
                  font.family: "Hack Nerd Font"
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              id: hoverArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launchApp(delegateRoot.modelData)
              onEntered: resultsList.currentIndex = delegateRoot.index
            }
          }

          // Empty state
          Text {
            anchors.centerIn: parent
            text: "No results found"
            color: root.theme.textMuted
            font.pixelSize: 14
            font.family: "Hack Nerd Font"
            visible: root.resultCount === 0 && searchInput.text !== ""
          }
        }

        // Footer hint
        RowLayout {
          Layout.fillWidth: true
          spacing: 16

          Row {
            spacing: 4
            Rectangle {
              width: hintUp.width + 8; height: 18; radius: 4; color: Style.moduleBg
              Text { id: hintUp; anchors.centerIn: parent; text: "↑↓"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text { text: "navigate"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEnter.width + 8; height: 18; radius: 4; color: Style.moduleBg
              Text { id: hintEnter; anchors.centerIn: parent; text: "⏎"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text { text: "launch"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEsc.width + 8; height: 18; radius: 4; color: Style.moduleBg
              Text { id: hintEsc; anchors.centerIn: parent; text: "esc"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text { text: "close"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Text { text: "=:calc  !:kagi  @:docs"; color: Style.text; font.pixelSize: 10; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignVCenter }
          Item { Layout.fillWidth: true }
        }
      }
    }
  }
}
