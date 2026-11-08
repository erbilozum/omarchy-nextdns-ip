import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import qs.Ui

Panel {
  id: panel

  property string lastText: ""
  property string errorText: ""
  property bool busy: false
  property bool online: true
  signal refreshRequested()

  ColumnLayout {
    spacing: 10

    Text {
      text: "NextDNS IP"
      font.bold: true
      color: Commons.Color.foreground
    }

    Text {
      visible: !panel.online
      text: "\uf071  No internet connection"
      font.bold: true
      color: Commons.Color.foreground
    }
    Text {
      visible: !panel.online
      text: "Updates resume automatically once you're back online."
      opacity: 0.7
      color: Commons.Color.foreground
    }

    Text {
      text: "Last update"
      opacity: 0.7
      color: Commons.Color.foreground
    }
    Text {
      text: panel.lastText
      color: Commons.Color.foreground
    }
    Text {
      visible: panel.errorText !== "" && panel.online
      text: panel.errorText
      opacity: 0.8
      color: Commons.Color.foreground
    }

    Button {
      text: panel.busy ? "Updating…" : "Refresh now"
      enabled: panel.online && !panel.busy
      onClicked: panel.refreshRequested()
    }
  }
}