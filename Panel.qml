import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.erbilozum.nextdns-ip"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // ---- UI state ----
  property bool showSettings: false
  property bool feedbackShown: false

  // ---- state read from the bar widget ----
  readonly property bool ndOnline: hostWidget ? hostWidget.ndOnline : true
  readonly property bool ndBusy: hostWidget ? hostWidget.ndBusy : false
  readonly property bool ndConfigured: hostWidget ? hostWidget.ndConfigured : false
  readonly property string ndUrlHint: hostWidget ? hostWidget.ndUrlHint : ""
  readonly property string ndStatus: hostWidget ? hostWidget.ndStatus : "none"
  readonly property string ndErr: hostWidget ? hostWidget.ndErr : ""
  readonly property string ndLastText: hostWidget ? hostWidget.ndLastText : ""
  readonly property string ndIcon: hostWidget ? hostWidget.ndIcon : "\uf132"
  readonly property string ndExtIp: hostWidget ? hostWidget.ndExtIp : ""
  readonly property int ndIntervalH: hostWidget ? hostWidget.ndIntervalH : 6
  readonly property real ndIpTs: hostWidget ? hostWidget.ndIpTs : 0
  readonly property string ndIpText:
    ndIpTs > 0 ? Qt.formatDateTime(new Date(ndIpTs * 1000), "yyyy-MM-dd HH:mm") : "Not yet"
  readonly property string ndLastResult: hostWidget ? hostWidget.ndLastResult : ""
  readonly property string ndLastDetail: hostWidget ? hostWidget.ndLastDetail : ""
  readonly property string uiFont: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property bool settingsVisible: showSettings || !ndConfigured

  readonly property string ndStatusText:
    ndStatus === "ok" ? "Up to date"
    : ndStatus === "error" ? "Failed" + (ndErr !== "" ? " (" + ndErr + ")" : "")
    : ndStatus === "nourl" ? "Not configured"
    : "Pending"

  readonly property string feedbackText:
    !feedbackShown ? ""
    : ndLastResult === "invalid" ? "That doesn't look like a NextDNS linked IP URL. Expected https://link-ip.nextdns.io/<id>/<token>"
    : ndLastResult === "rejected" ? "NextDNS did not accept this URL (" + ndLastDetail + "). Check the link and try again."
    : ndLastResult === "unreachable" ? "Couldn't reach NextDNS. Check your connection and try again."
    : ndLastResult === "offline" ? "No internet connection. Connect and try again."
    : ndLastResult === "saved" ? "Saved"
    : "Verifying…"

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function saveUrl() {
    const url = urlField.text.trim()
    if (url.length === 0 || !root.hostWidget) return
    root.feedbackShown = true
    root.hostWidget.ndSaveUrl(url)
  }

  // After a successful save: clear the field (the token should not stay on screen)
  onNdLastResultChanged: {
    if (ndLastResult === "saved") {
      urlField.text = ""
      showSettings = false
      feedbackShown = false
    }
  }

  // Keep the slider in sync with the saved value unless the user is dragging it
  onNdIntervalHChanged: if (!hoursSlider.dragging) hoursSlider.value = ndIntervalH

  Process {
    id: opener
    command: ["xdg-open", "https://my.nextdns.io"]
  }

  // ---- small reusable pieces ----
  component InfoRow: Item {
    property string label: ""
    property string value: ""
    property color fg: "white"
    property string fontFamily: ""

    width: parent ? parent.width : 0
    height: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    Text {
      id: labelText
      anchors.left: parent.left
      text: parent.label
      color: parent.fg
      opacity: 0.6
      font.family: parent.fontFamily
      font.pixelSize: Style.space(12)
    }
    Text {
      id: valueText
      anchors.right: parent.right
      text: parent.value
      color: parent.fg
      font.family: parent.fontFamily
      font.pixelSize: Style.space(12)
    }
  }

  component PillButton: Rectangle {
    id: pill
    property string label: ""
    property bool active: true
    property color fg: "white"
    property string fontFamily: ""
    signal activated()

    width: parent ? parent.width : 0
    height: Style.space(34)
    radius: Style.space(4)
    color: active && area.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.12) : "transparent"
    border.width: 1
    border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.5)
    opacity: active ? 1.0 : 0.4

    Text {
      anchors.centerIn: parent
      text: pill.label
      color: pill.fg
      font.family: pill.fontFamily
      font.pixelSize: Style.space(12)
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      enabled: pill.active
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.activated()
    }
  }

  component UrlField: Rectangle {
    id: field
    property alias text: input.text
    property string placeholder: ""
    property color fg: "white"
    property string fontFamily: ""
    signal submitted()

    width: parent ? parent.width : 0
    height: Style.space(34)
    radius: Style.space(4)
    color: "transparent"
    clip: true
    border.width: 1
    border.color: Qt.rgba(fg.r, fg.g, fg.b, input.activeFocus ? 0.9 : 0.5)

    Text {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      verticalAlignment: Text.AlignVCenter
      visible: input.text.length === 0
      text: field.placeholder
      color: field.fg
      opacity: 0.4
      elide: Text.ElideRight
      font.family: field.fontFamily
      font.pixelSize: Style.space(12)
    }

    TextInput {
      id: input
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      verticalAlignment: TextInput.AlignVCenter
      color: field.fg
      selectByMouse: true
      clip: true
      font.family: field.fontFamily
      font.pixelSize: Style.space(12)
      onAccepted: field.submitted()
    }
  }

  // Draggable 1-24 hour slider, snaps to whole hours
  component HourSlider: Item {
    id: sl
    property int value: 6
    property int from: 1
    property int to: 24
    property color fg: "white"
    readonly property bool dragging: dragArea.pressed
    signal committed(int hours)

    width: parent ? parent.width : 0
    height: Style.space(24)

    readonly property real frac: (value - from) / (to - from)

    Rectangle {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: Style.space(4)
      radius: height / 2
      color: Qt.rgba(sl.fg.r, sl.fg.g, sl.fg.b, 0.2)
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: handle.x + handle.width / 2
      height: track.height
      radius: height / 2
      color: Qt.rgba(sl.fg.r, sl.fg.g, sl.fg.b, 0.6)
    }
    Rectangle {
      id: handle
      width: Style.space(16)
      height: width
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      x: sl.frac * (sl.width - width)
      color: sl.fg
    }

    MouseArea {
      id: dragArea
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor

      function setFrom(mx) {
        const f = Math.max(0, Math.min(1, (mx - handle.width / 2) / (sl.width - handle.width)))
        sl.value = Math.round(sl.from + f * (sl.to - sl.from))
      }

      onPressed: function(mouse) { setFrom(mouse.x) }
      onPositionChanged: function(mouse) { if (pressed) setFrom(mouse.x) }
      onReleased: sl.committed(sl.value)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // ---- header: icon box, title, subtitle ----
        Item {
          width: parent.width
          height: iconBox.height

          Rectangle {
            id: iconBox
            width: Style.space(40)
            height: width
            radius: Style.space(4)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.5)

            Text {
              anchors.centerIn: parent
              text: root.ndIcon
              color: root.barForeground
              font.family: root.uiFont
              font.pixelSize: Style.space(20)
            }
          }

          Column {
            anchors.left: iconBox.right
            anchors.leftMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "NextDNS IP"
              color: root.barForeground
              font.family: root.uiFont
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
            Text {
              text: "LINKED IP UPDATER"
              color: root.barForeground
              opacity: 0.6
              font.family: root.uiFont
              font.pixelSize: Style.space(10)
              font.letterSpacing: 1
            }
          }
        }

        // ---- offline warning ----
        Rectangle {
          visible: !root.ndOnline
          width: parent.width
          height: warning.implicitHeight + Style.space(16)
          radius: Style.space(4)
          color: "transparent"
          border.width: 1
          border.color: root.barForeground

          Text {
            id: warning
            anchors.fill: parent
            anchors.margins: Style.space(8)
            text: "\uf071  No internet connection. Updates resume automatically once you're back online."
            color: root.barForeground
            wrapMode: Text.WordWrap
            font.family: root.uiFont
            font.pixelSize: Style.space(12)
          }
        }

        // ---- first-run setup guide ----
        Column {
          visible: !root.ndConfigured
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: parent.width
            height: setupText.implicitHeight + Style.space(20)
            radius: Style.space(4)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.5)

            Text {
              id: setupText
              anchors.fill: parent
              anchors.margins: Style.space(10)
              wrapMode: Text.WordWrap
              color: root.barForeground
              font.family: root.uiFont
              font.pixelSize: Style.space(12)
              lineHeight: 1.2
              text: "Setup required\n\n"
                + "This plugin keeps your NextDNS linked IP up to date. It only works with a "
                + "NextDNS account and a configuration (profile) you have already created.\n\n"
                + "1. Sign in at my.nextdns.io\n"
                + "2. Open your configuration, then the Setup tab\n"
                + "3. Under \"Linked IP\", copy the link\n"
                + "4. Paste it below and press Save"
            }
          }

          PillButton {
            label: "Open my.nextdns.io"
            fg: root.barForeground
            fontFamily: root.uiFont
            onActivated: opener.running = true
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: root.barForeground
          opacity: 0.2
        }

        // ---- info rows ----
        InfoRow {
          label: "Status"
          value: root.ndStatusText
          fg: root.barForeground
          fontFamily: root.uiFont
        }
        InfoRow {
          label: "Last update"
          value: root.ndLastText
          fg: root.barForeground
          fontFamily: root.uiFont
        }
        InfoRow {
          label: "External IP"
          value: root.ndExtIp !== "" ? root.ndExtIp : "Unknown"
          fg: root.barForeground
          fontFamily: root.uiFont
        }
        InfoRow {
          label: "Last IP check"
          value: root.ndIpText
          fg: root.barForeground
          fontFamily: root.uiFont
        }
        InfoRow {
          label: "Check IP every"
          value: root.ndIntervalH + (root.ndIntervalH === 1 ? " hour" : " hours")
          fg: root.barForeground
          fontFamily: root.uiFont
        }
        InfoRow {
          label: "Internet"
          value: root.ndOnline ? "Online" : "Offline"
          fg: root.barForeground
          fontFamily: root.uiFont
        }
        InfoRow {
          label: "URL"
          value: root.ndConfigured
            ? "Configured" + (root.ndUrlHint !== "" ? " (" + root.ndUrlHint + ")" : "")
            : "Not set"
          fg: root.barForeground
          fontFamily: root.uiFont
        }

        Rectangle {
          width: parent.width
          height: 1
          color: root.barForeground
          opacity: 0.2
        }

        // ---- manual update ----
        Text {
          text: "MANUAL UPDATE"
          color: root.barForeground
          opacity: 0.6
          font.family: root.uiFont
          font.pixelSize: Style.space(10)
          font.letterSpacing: 1
        }

        PillButton {
          label: root.ndBusy ? "Working…" : "Refresh now"
          active: root.ndOnline && !root.ndBusy && root.ndConfigured
          fg: root.barForeground
          fontFamily: root.uiFont
          onActivated: if (root.hostWidget) root.hostWidget.ndRun("force")
        }

        // ---- settings (just a button once a URL exists) ----
        PillButton {
          visible: root.ndConfigured && !root.showSettings
          label: "Settings"
          fg: root.barForeground
          fontFamily: root.uiFont
          onActivated: root.showSettings = true
        }

        Column {
          id: settingsBox
          width: parent.width
          spacing: Style.space(8)
          visible: root.settingsVisible

          Rectangle {
            width: parent.width
            height: 1
            color: root.barForeground
            opacity: 0.2
          }

          Text {
            text: "NEXTDNS LINKED IP URL"
            color: root.barForeground
            opacity: 0.6
            font.family: root.uiFont
            font.pixelSize: Style.space(10)
            font.letterSpacing: 1
          }

          UrlField {
            id: urlField
            placeholder: "https://link-ip.nextdns.io/xxxxxx/xxxxxxxxxxxxxxxx"
            fg: root.barForeground
            fontFamily: root.uiFont
            onSubmitted: root.saveUrl()
            onTextChanged: root.feedbackShown = false
          }

          Text {
            width: parent.width
            text: "The link is checked with NextDNS before it is saved."
            color: root.barForeground
            opacity: 0.6
            wrapMode: Text.WordWrap
            font.family: root.uiFont
            font.pixelSize: Style.space(11)
          }

          Text {
            visible: root.feedbackText !== ""
            width: parent.width
            text: root.feedbackText
            color: root.barForeground
            wrapMode: Text.WordWrap
            font.family: root.uiFont
            font.pixelSize: Style.space(12)
            font.bold: true
          }

          PillButton {
            label: root.ndBusy && root.feedbackShown ? "Verifying…" : "Verify and save"
            active: urlField.text.trim().length > 0 && !root.ndBusy
            fg: root.barForeground
            fontFamily: root.uiFont
            onActivated: root.saveUrl()
          }

          PillButton {
            visible: root.ndConfigured
            label: "Remove saved URL"
            active: !root.ndBusy
            fg: root.barForeground
            fontFamily: root.uiFont
            onActivated: if (root.hostWidget) root.hostWidget.ndClearUrl()
          }

          Rectangle {
            width: parent.width
            height: 1
            color: root.barForeground
            opacity: 0.2
          }

          Text {
            text: "CHECK IP EVERY " + hoursSlider.value + (hoursSlider.value === 1 ? " HOUR" : " HOURS")
            color: root.barForeground
            opacity: 0.6
            font.family: root.uiFont
            font.pixelSize: Style.space(10)
            font.letterSpacing: 1
          }

          HourSlider {
            id: hoursSlider
            fg: root.barForeground
            value: 6
            onCommitted: function(hours) {
              if (root.hostWidget) root.hostWidget.ndSetInterval(hours)
            }
          }

          Item {
            width: parent.width
            height: rangeMin.implicitHeight

            Text {
              id: rangeMin
              anchors.left: parent.left
              text: "1 h"
              color: root.barForeground
              opacity: 0.5
              font.family: root.uiFont
              font.pixelSize: Style.space(10)
            }
            Text {
              anchors.right: parent.right
              text: "24 h"
              color: root.barForeground
              opacity: 0.5
              font.family: root.uiFont
              font.pixelSize: Style.space(10)
            }
          }

          Text {
            width: parent.width
            text: "NextDNS is contacted only when your IP address has changed. The IP is also checked after boot, reconnect and resume."
            color: root.barForeground
            opacity: 0.6
            wrapMode: Text.WordWrap
            font.family: root.uiFont
            font.pixelSize: Style.space(11)
          }

          PillButton {
            visible: root.ndConfigured
            label: "Close settings"
            fg: root.barForeground
            fontFamily: root.uiFont
            onActivated: {
              urlField.text = ""
              root.feedbackShown = false
              root.showSettings = false
            }
          }
        }
      }
    }
  }
}