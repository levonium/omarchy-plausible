import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "levonium.plausible"
  ipcTarget: "levonium.plausible"

  // Resolve paths from this file so the plugin works wherever it is installed.
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

  // Each site is rendered as its own section. Sites are read from sites.json next
  // to this file (git-ignored; see sites.example.json). A "sites" list in this
  // widget's shell.json entry, if present, overrides it.
  property var fileSites: []
  property string sitesError: ""
  readonly property var settingSites: setting("sites", [])
  readonly property var sites: settingSites.length > 0 ? settingSites : fileSites

  readonly property int refreshSeconds: Math.max(15, parseInt(setting("refreshSeconds", 60), 10) || 60)

  // Loaded from a plain-text file kept out of shell.json (and thus out of
  // anything that might sync/back it up alongside the rest of the config).
  property string apiKey: ""

  function refreshAll() {
    for (var i = 0; i < sectionRepeater.count; i++) {
      var item = sectionRepeater.itemAt(i)
      if (item && item.refresh) item.refresh()
    }
  }

  FileView {
    id: secretFile
    path: root.pluginDir + "/secret.conf"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.apiKey = text().trim()
    onLoadFailed: root.apiKey = ""
  }

  FileView {
    id: sitesFile
    path: root.pluginDir + "/sites.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        if (!Array.isArray(parsed)) throw new Error("expected a list")
        root.fileSites = parsed
          .filter(function(s) { return s && typeof s.domain === "string" && s.domain !== "" })
          .map(function(s) { return { domain: s.domain, label: s.label || s.domain } })
        root.sitesError = ""
      } catch (e) {
        root.fileSites = []
        root.sitesError = "sites.json is not valid: " + e.message
      }
    }
    onLoadFailed: { root.fileSites = []; root.sitesError = "" }
  }

  onSitesChanged: if (opened) Qt.callLater(root.refreshAll)

  onOpenedChanged: if (opened) Qt.callLater(root.refreshAll)

  Timer {
    interval: root.refreshSeconds * 1000
    running: root.opened
    repeat: true
    onTriggered: root.refreshAll()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""  // nf-fa-bar_chart
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refreshAll() }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            title: "Analytics"
            meta: root.apiKey === ""
              ? "No API key configured"
              : "Plausible · refreshes every " + root.refreshSeconds + "s"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            iconComponent: Component {
              Text {
                text: ""
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              PanelActionButton {
                iconText: ""  // nf-fa-refresh
                tooltipText: "Refresh"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: root.refreshAll()
              }
            }
          }

          Text {
            visible: root.apiKey === ""
            width: parent.width
            text: "Add your Plausible Stats API key to secret.conf in this plugin's folder, then reopen this panel."
            color: root.bar.urgent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            visible: root.apiKey !== "" && root.sites.length === 0
            width: parent.width
            text: root.sitesError !== "" ? root.sitesError
              : "No sites configured. Copy sites.example.json to sites.json in this plugin's folder and list your sites (see the README)."
            color: root.bar.urgent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Repeater {
            id: sectionRepeater
            model: root.sites

            AnalyticsSection {
              required property var modelData
              required property int index
              width: panelColumn.width
              domain: modelData.domain
              label: modelData.label
              showSeparator: index > 0
            }
          }
        }
      }
    }
  }

  component AnalyticsSection: Column {
    id: section
    property string domain: ""
    property string label: ""
    property bool showSeparator: false

    property int realtimeVisitors: -1
    property int todayVisitors: -1
    property int todayPageviews: -1
    property int organicVisitors: -1
    property int referralVisitors: -1
    property int aiVisitors: -1

    spacing: Style.space(6)

    function refresh() {
      if (root.apiKey === "") return
      if (!realtimeProc.running) realtimeProc.running = true
      if (!totalsProc.running) totalsProc.running = true
      if (!channelProc.running) channelProc.running = true
    }

    Process {
      id: realtimeProc
      command: ["curl", "-fsS", "--max-time", "6",
        "-H", "Authorization: Bearer " + root.apiKey,
        "https://plausible.io/api/v1/stats/realtime/visitors?site_id=" + encodeURIComponent(section.domain)]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          var n = Model.parseRealtime(text)
          if (n !== null) section.realtimeVisitors = n
        }
      }
    }

    Process {
      id: totalsProc
      command: ["curl", "-fsS", "--max-time", "8", "-X", "POST",
        "https://plausible.io/api/v2/query",
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " + root.apiKey,
        "--data-binary", JSON.stringify({
          site_id: section.domain,
          metrics: ["visitors", "pageviews"],
          date_range: "day"
        })]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          var t = Model.parseTotals(text)
          if (t) {
            section.todayVisitors = t.visitors
            section.todayPageviews = t.pageviews
          }
        }
      }
    }

    Process {
      id: channelProc
      command: ["curl", "-fsS", "--max-time", "8", "-X", "POST",
        "https://plausible.io/api/v2/query",
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " + root.apiKey,
        "--data-binary", JSON.stringify({
          site_id: section.domain,
          metrics: ["visitors"],
          date_range: "day",
          dimensions: ["visit:channel"]
        })]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          var organic = Model.parseChannelVisitors(text, "Organic Search")
          var referral = Model.parseChannelVisitors(text, "Referral")
          var ai = Model.parseChannelVisitors(text, "AI Assistants")
          if (organic !== null) section.organicVisitors = organic
          if (referral !== null) section.referralVisitors = referral
          if (ai !== null) section.aiVisitors = ai
        }
      }
    }

    PanelSeparator {
      visible: section.showSeparator
      foreground: root.bar.foreground
    }

    Item {
      width: parent.width
      implicitHeight: Math.max(siteIcon.implicitHeight, siteLabels.implicitHeight)

      Text {
        id: siteIcon
        text: ""  // nf-fa-globe
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: siteLabels
        anchors.left: siteIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          text: section.label
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }
        Text {
          text: section.domain
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    Row {
      id: row1
      width: parent.width
      spacing: Style.space(8)

      readonly property real tileWidth: (width - 2 * spacing) / 3

      StatTile {
        width: row1.tileWidth
        title: "REAL-TIME"
        value: section.realtimeVisitors < 0 ? "—" : Model.formatNumber(section.realtimeVisitors)
        live: section.realtimeVisitors >= 0
      }
      StatTile {
        width: row1.tileWidth
        title: "TODAY"
        value: section.todayVisitors < 0 ? "—" : Model.formatNumber(section.todayVisitors)
      }
      StatTile {
        width: row1.tileWidth
        title: "PAGEVIEWS"
        value: section.todayPageviews < 0 ? "—" : Model.formatNumber(section.todayPageviews)
      }
    }

    Row {
      id: row2
      width: parent.width
      spacing: Style.space(8)

      StatTile {
        width: row1.tileWidth
        title: "ORGANIC"
        value: section.organicVisitors < 0 ? "—" : Model.formatNumber(section.organicVisitors)
      }
      StatTile {
        width: row1.tileWidth
        title: "REFERRAL"
        value: section.referralVisitors < 0 ? "—" : Model.formatNumber(section.referralVisitors)
      }
      StatTile {
        width: row1.tileWidth
        title: "AI ASSISTANT"
        value: section.aiVisitors < 0 ? "—" : Model.formatNumber(section.aiVisitors)
      }
    }
  }

  component StatTile: Rectangle {
    id: tile
    property string title: ""
    property string value: "—"
    property bool live: false

    implicitHeight: Style.space(44)
    radius: Style.cornerRadius
    color: Style.normalFillFor(root.bar.foreground, Color.accent)

    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(2)

      Row {
        spacing: Style.space(6)

        Rectangle {
          visible: tile.live
          width: Style.space(6)
          height: Style.space(6)
          radius: width / 2
          color: Color.accent
          anchors.verticalCenter: parent.verticalCenter

          SequentialAnimation on opacity {
            running: tile.live
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.25; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.25; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
          }
        }

        Text {
          text: tile.title
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }
      }

      Text {
        text: tile.value
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        elide: Text.ElideRight
        width: parent.width
      }
    }
  }
}
