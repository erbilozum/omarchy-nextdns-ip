import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.erbilozum.nextdns-ip"

  // ---- state shown in the bar and the panel ----
  property real ndOkTs: 0
  property string ndStatus: "none"
  property bool ndOnline: true        // assume online until the first check says otherwise
  property bool ndBusy: false
  property bool ndConfigured: false
  property string ndLastResult: ""    // "saved" | "invalid" after a settings save
  property var ndQueued: null

  readonly property string ndScript:
    Qt.resolvedUrl("nextdns-ip.sh").toString().replace("file://", "")

  readonly property string ndLastText:
    ndStatus === "nourl" ? "URL not configured"
    : ndOkTs > 0 ? Qt.formatDateTime(new Date(ndOkTs * 1000), "yyyy-MM-dd HH:mm")
    : "No update yet"

  readonly property string ndIcon:
    !ndOnline || ndStatus === "error" || ndStatus === "nourl" ? "\uf071" : "\uf132"

  // ---- panel lifecycle (same contract as the built-in clock) ----
  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  // ---- update logic ----
  function ndRun(mode, arg) {
    if (proc.running) {
      // keep user actions that arrive while another run is busy
      if (mode === "force" || mode === "seturl") ndQueued = { mode: mode, arg: arg }
      return
    }
    ndBusy = true
    proc.command = arg !== undefined
      ? ["bash", ndScript, mode, arg]
      : ["bash", ndScript, mode]
    proc.running = true
  }

  function ndSaveUrl(url) {
    ndLastResult = ""
    ndRun("seturl", url)
  }

  Process {
    id: proc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const s = JSON.parse(text)
          root.ndOkTs = s.ok_ts
          root.ndStatus = s.status
          root.ndOnline = s.online === 1
          root.ndConfigured = s.configured === 1
          if (s.result) root.ndLastResult = s.result
        } catch (e) {}
        root.ndBusy = false
      }
    }
    onExited: function(exitCode, exitStatus) {
      root.ndBusy = false
      if (root.ndQueued) {
        const q = root.ndQueued
        root.ndQueued = null
        root.ndRun(q.mode, q.arg)
      }
    }
  }

  // Check the schedule every minute; the script decides whether to update
  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.ndRun("tick")
  }

  // While the panel is open, re-check connectivity every 3 seconds
  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.ndRun("check")
  }

  onOpenedChanged: if (opened) ndRun("check")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.ndIcon
    tooltipText: root.ndOnline
      ? "NextDNS IP · " + root.ndLastText
      : "NextDNS IP · No internet connection"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}