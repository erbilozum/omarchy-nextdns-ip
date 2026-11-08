import QtQuick
import Quickshell
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
  readonly property string ndStatus: hostWidget ? hostWidget.ndStatus : "none"
  readonly property string ndLastText: hostWidget ? hostWidget.ndLastText : ""
  readonly property string ndIcon: hostWidget ? hostWidget.ndIcon : "\uf132"
  readonly property string ndLastResult: hostWidget ? hostWidget.ndLastResult : ""
  readonly property string uiFont: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property bool settingsVisible: showSettings || !ndConfigured

  readonly property string ndStatusText:
    ndStatus === "ok" ? "Up to date"
    : ndStatus === "error" ? "Last attempt failed"
    : ndStatus === "nourl" ? "Not configured"
    : "Pending"

  readonly property string feedbackText:
    !feedbackShown ? ""
    : ndLastResult === "invalid" ? "Invalid URL. Expected https://link-ip.nextdns.io/<id>/<token>"
    : ndLastResult === "saved" ? "Saved"
    : "Saving…"

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
          label: "Internet"
          value: root.ndOnline ? "Online" : "Offline"
          fg: root.barForeground
          fontFamily: root.uiFont
        }
        InfoRow {
          label: "URL"
          value: root.ndConfigured ? "Configured" : "Not set"
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
          label: root.ndBusy ? "Updating…" : "Refresh now"
          active: root.ndOnline && !root.ndBusy && root.ndConfigured
          fg: root.barForeground
          fontFamily: root.uiFont
          onActivated: if (root.hostWidget) root.hostWidget.ndRun("force")
        }

        // ---- settings (only a button once a URL exists) ----
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
            text: "Enter your own linked IP URL. Find it in NextDNS → Setup → Linked IP."
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
            label: "Save"
            active: urlField.text.trim().length > 0
            fg: root.barForeground
            fontFamily: root.uiFont
            onActivated: root.saveUrl()
          }

          PillButton {
            visible: root.ndConfigured
            label: "Cancel"
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