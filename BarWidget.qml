import QtQuick
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root

  property real okTs: 0
  property string status: "none"
  property bool online: true      // assume online until the first check says otherwise
  property bool busy: false
  property bool panelOpen: false

  readonly property string script:
    Qt.resolvedUrl("nextdns-ip.sh").toString().replace("file://", "")

  readonly property string lastText:
    status === "nourl" ? "URL not configured"
    : okTs > 0 ? Qt.formatDateTime(new Date(okTs * 1000), "yyyy-MM-dd HH:mm")
    : "No update yet"
  readonly property string errorText:
    status === "error" ? "Last attempt failed" : ""

  function run(mode) {
    if (proc.running) return
    busy = true
    proc.command = ["bash", script, mode]
    proc.running = true
  }

  Process {
    id: proc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const s = JSON.parse(text)
          root.okTs = s.ok_ts
          root.status = s.status
          root.online = s.online === 1
        } catch (e) {}
        root.busy = false
      }
    }
  }

  // Check the schedule every minute; the script decides whether to update
  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.run("tick")
  }

  // While the panel is open, re-check connectivity every 3 seconds
  Timer {
    interval: 3000
    running: root.panelOpen
    repeat: true
    onTriggered: root.run("check")
  }

  onPanelOpenChanged: if (panelOpen) run("check")

  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight

  Text {
    id: icon
    text: !root.online || root.status === "error" || root.status === "nourl" ? "\uf071" : "\uf132"
    color: Commons.Color.foreground
    opacity: root.online && root.status === "ok" ? 1.0 : 0.6
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.panelOpen = !root.panelOpen
  }

  Loader {
    active: root.panelOpen
    source: "Panel.qml"
    onLoaded: {
      item.lastText = Qt.binding(() => root.lastText)
      item.errorText = Qt.binding(() => root.errorText)
      item.busy = Qt.binding(() => root.busy)
      item.online = Qt.binding(() => root.online)
      item.refreshRequested.connect(() => root.run("force"))
    }
  }
}