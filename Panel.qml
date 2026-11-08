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

  // ---- state read from the bar widget ----
  readonly property bool ndOnline: hostWidget ? hostWidget.ndOnline : true
  readonly property bool ndBusy: hostWidget ? hostWidget.ndBusy : false
  readonly property string ndStatus: hostWidget ? hostWidget.ndStatus : "none"
  readonly property string ndLastText: hostWidget ? hostWidget.ndLastText : ""
  readonly property string ndIcon: hostWidget ? hostWidget.ndIcon : "\uf132"
  readonly property string uiFont: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property string ndStatusText:
    ndStatus === "ok" ? "Up to date"
    : ndStatus === "error" ? "Last attempt failed"
    : ndStatus === "nourl" ? "Not configured"
    : "Pending"

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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
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

        // ---- divider ----
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

        // ---- divider ----
        Rectangle {
          width: parent.width
          height: 1
          color: root.barForeground
          opacity: 0.2
        }

        // ---- action ----
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
          active: root.ndOnline && !root.ndBusy
          fg: root.barForeground
          fontFamily: root.uiFont
          onActivated: if (root.hostWidget) root.hostWidget.ndRun("force")
        }
      }
    }
  }
}