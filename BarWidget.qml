import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.erbilozum.nextdns-ip"

  // ---- state shown in the bar and the panel ----
  property real ndOkTs: 0
  property string ndStatus: "none"
  property string ndErr: ""
  property bool ndOnline: true        // assume online until the first check says otherwise
  property bool ndBusy: false         // true only while a user-triggered action runs
  property bool ndConfigured: false
  property string ndUrlHint: ""
  property string ndExtIp: ""
  property int ndIntervalH: 6
  property real ndIpTs: 0
  property string ndLastResult: ""    // result of the last URL save
  property string ndLastDetail: ""
  property string ndMode: ""          // mode of the process that is running now
  property var ndQueued: null

  readonly property string ndScript:
    Qt.resolvedUrl("nextdns-ip.sh").toString().replace("file://", "")

  readonly property string ndLastText:
    ndStatus === "nourl" ? "URL not configured"
    : ndOkTs > 0 ? Qt.formatDateTime(new Date(ndOkTs * 1000), "yyyy-MM-dd HH:mm")
    : "No update yet"

  readonly property string ndIcon:
    !ndOnline || !ndConfigured || ndStatus === "error" || ndStatus === "nourl" ? "\uf071" : "\uf132"

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

  // Actions the user starts by hand; only these make the panel show "Working…"
  function ndIsUser(mode) {
    return mode === "force" || mode === "seturl" || mode === "clearurl"
  }

  function ndRun(mode, arg) {
    if (ndIsUser(mode)) ndBusy = true

    if (proc.running) {
      // keep user actions that arrive while another run is busy
      if (ndIsUser(mode) || mode === "setinterval")
        ndQueued = { mode: mode, arg: arg }
      return
    }

    ndMode = mode
    proc.command = arg !== undefined
      ? ["bash", ndScript, mode, arg]
      : ["bash", ndScript, mode]
    proc.running = true
  }

  function ndSaveUrl(url) {
    ndLastResult = ""
    ndLastDetail = ""
    ndRun("seturl", url)
  }

  function ndClearUrl() {
    ndLastResult = ""
    ndRun("clearurl")
  }

  function ndSetInterval(hours) {
    ndRun("setinterval", String(hours))
  }

  Process {
    id: proc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const s = JSON.parse(text)
          root.ndOkTs = s.ok_ts
          root.ndStatus = s.status
          root.ndErr = s.err || ""
          root.ndOnline = s.online === 1
          root.ndConfigured = s.configured === 1
          root.ndUrlHint = s.url_hint || ""
          root.ndExtIp = s.ext_ip || ""
          root.ndIpTs = s.ip_ts || 0
          if (s.interval_h) root.ndIntervalH = s.interval_h
          if (s.result && s.result.indexOf("interval") !== 0) {
            root.ndLastResult = s.result
            root.ndLastDetail = s.detail || ""
          }
        } catch (e) {}
        if (root.ndIsUser(root.ndMode) && !root.ndQueued) root.ndBusy = false
      }
    }
    onExited: function(exitCode, exitStatus) {
      if (root.ndQueued) {
        const q = root.ndQueued
        root.ndQueued = null
        root.ndRun(q.mode, q.arg)
      } else if (root.ndIsUser(root.ndMode)) {
        root.ndBusy = false
      }
    }
  }

  // Check the schedule every minute; the script decides what to do
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

  // Opening the panel also refreshes the external IP
  onOpenedChanged: if (opened) ndRun("ip")

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
    tooltipText: !root.ndConfigured
      ? "NextDNS IP · Setup needed, click to enter your URL"
      : root.ndOnline
        ? "NextDNS IP · " + root.ndLastText
        : "NextDNS IP · No internet connection"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}