import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.nicolas.oma-connect"
  manageIpc: false

  // The model is deliberately local for now. The next slice can replace this
  // state with a service without changing the bar/panel lifecycle contract.
  property string connectionState: "Ready"
  property string connectionMessage: "The connection service is ready to be added."

  property var anchorItem: null
  property var hostWidget: null

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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(280))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        Text {
          width: parent.width
          text: "Oma Connect"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Rectangle {
          width: parent.width
          height: Style.space(40)
          radius: Style.space(6)
          color: Qt.rgba(1, 1, 1, 0.08)

          Row {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(10)
              height: width
              radius: width / 2
              anchors.verticalCenter: parent.verticalCenter
              color: "#7bd88f"
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.connectionState
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
            }
          }
        }

        Text {
          width: parent.width
          text: root.connectionMessage
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
