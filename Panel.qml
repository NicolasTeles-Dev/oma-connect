import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.nicolas.oma-connect"
  manageIpc: false

  // The model is deliberately local for now. The next slice can replace this
  // state with a service without changing the bar/panel lifecycle contract.
  property string connectionState: "Ready"
  property string connectionMessage: "The connection service is ready to be added."
  readonly property color panelForeground: Commons.Color.popups.text

  property var anchorItem: null
  property var hostWidget: null

  readonly property string servicePath:
    Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.nicolas.oma-connect/service/oma-connect-service.mjs"
  readonly property bool serviceRequired:
    !device.paused && (device.pairingMode || device.hasDevice)

  DeviceModel {
    id: device
  }

  Process {
    id: connectionService
    command: ["node", root.servicePath, "--name", "Meu Omarchy"]
    running: root.serviceRequired

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "") console.warn("oma-connect service", text.trim())
      }
    }
  }

  Process {
    id: forgetProcess
    command: ["node", root.servicePath, "--forget"]
    onExited: device.clear()
  }

  function forgetDevice() {
    device.paused = false
    device.pairingMode = false
    if (!forgetProcess.running) forgetProcess.running = true
    else device.clear()
  }

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
    // Keep enough room for the demo device details while the model is still
    // local. The fitted height still adapts when the real service is added.
    contentHeight: panel.fittedContentHeight(Math.max(content.implicitHeight, Style.space(180)))

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
          color: root.panelForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Rectangle {
          visible: device.hasDevice
          width: parent.width
          height: Style.space(40)
          radius: Style.space(6)
          color: Qt.rgba(
            root.panelForeground.r,
            root.panelForeground.g,
            root.panelForeground.b,
            0.08
          )

          Row {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(10)
              height: width
              radius: width / 2
              anchors.verticalCenter: parent.verticalCenter
              color: device.connected
                ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.7)
                : Qt.rgba(Commons.Color.muted.r, Commons.Color.muted.g, Commons.Color.muted.b, 0.7)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: device.statusText
              color: root.panelForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
            }
          }
        }

        Text {
          visible: device.hasDevice
          width: parent.width
          text: device.hasDevice
            ? device.deviceName + " · " + device.deviceType
            : root.connectionMessage
          color: root.panelForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          wrapMode: Text.WordWrap
        }

        Text {
          visible: device.hasDevice
          width: parent.width
          text: "Battery: " + device.batteryText
          color: root.panelForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
        }

        Text {
          visible: device.hasDevice && device.lastUpdated !== ""
          width: parent.width
          text: "Updated: " + device.lastUpdated
          color: root.panelForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
        }

        Column {
          visible: device.hasDevice
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: parent.width
            height: Style.space(40)
            radius: Style.space(6)
            color: Qt.rgba(root.panelForeground.r, root.panelForeground.g, root.panelForeground.b, 0.08)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(12)
              text: device.paused ? "Resume connection" : "Pause connection"
              color: root.panelForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
            }

            MouseArea {
              anchors.fill: parent
              onClicked: device.paused = !device.paused
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(40)
            radius: Style.space(6)
            color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.12)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(12)
              text: "Forget device"
              color: root.panelForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.forgetDevice()
            }
          }
        }

        Column {
          visible: !device.hasDevice
          width: parent.width
          spacing: Style.space(12)

          Text {
            width: parent.width
            text: "No device connected"
            color: root.panelForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            width: parent.width
            text: "Enable pairing mode to make Oma Connect discoverable."
            color: root.panelForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            wrapMode: Text.WordWrap
          }

          Rectangle {
            width: parent.width
            height: Style.space(48)
            radius: Style.space(2)
            color: device.pairingMode
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.14)
              : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.08)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - toggle.width - Style.space(10)
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: "Pairing mode"
                  color: root.panelForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }

                Text {
                  width: parent.width
                  text: device.pairingMode ? "Discoverable" : "Off"
                  color: root.panelForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                }
              }

              Rectangle {
                id: toggle
                width: Style.space(42)
                height: Style.space(24)
                radius: Style.space(2)
                anchors.verticalCenter: parent.verticalCenter
                color: device.pairingMode
                  ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.65)
                  : Qt.rgba(Commons.Color.muted.r, Commons.Color.muted.g, Commons.Color.muted.b, 0.5)

                Rectangle {
                  width: Style.space(18)
                  height: width
                  radius: Style.space(2)
                  anchors.verticalCenter: parent.verticalCenter
                  x: device.pairingMode
                    ? parent.width - width - Style.space(3)
                    : Style.space(3)
                  color: root.panelForeground
                  Behavior on x { NumberAnimation { duration: 120 } }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: device.togglePairingMode()
            }
          }
        }
      }
    }
  }
}
