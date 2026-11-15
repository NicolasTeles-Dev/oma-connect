import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  // Temporary fixture used to style and test the panel before the connection
  // service exists. Set demoMode to false when the real service is connected.
  property bool demoMode: false
  property bool hasDevice: demoMode
  property string deviceName: demoMode ? "Oma Demo" : ""
  property string deviceType: demoMode ? "Phone" : ""
  property bool connected: demoMode
  property int batteryPercent: demoMode ? 78 : -1
  property bool charging: false
  property string lastUpdated: demoMode ? "Just now" : ""
  property bool pairingMode: false
  property bool paused: false

  function clear() {
    hasDevice = false
    demoMode = false
    deviceName = ""
    deviceType = ""
    connected = false
    batteryPercent = -1
    charging = false
    lastUpdated = ""
  }

  readonly property string stateHome:
    Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string statePath: stateHome + "/oma-connect/paired-device.json"

  function applyState(value) {
    try {
      var state = JSON.parse(value || "{}")
      if (!state.mobileDevice && state.connected !== true) return
      hasDevice = true
      demoMode = false
      deviceName = state.mobileDevice && state.mobileDevice.name
        ? state.mobileDevice.name : "Paired device"
      deviceType = state.mobileDevice && state.mobileDevice.platform
        ? state.mobileDevice.platform : "Phone"
      connected = state.connected === true
      batteryPercent = state.mobileDevice && typeof state.mobileDevice.battery === "number"
        ? state.mobileDevice.battery : -1
      charging = connected && state.mobileDevice && state.mobileDevice.charging === true
      lastUpdated = connected ? "Just now" : "Last seen earlier"
    } catch (error) {
      console.warn("oma-connect: invalid paired-device state", error)
    }
  }

  property FileView stateFile: FileView {
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyState(text())
    onLoadFailed: root.clear()
  }

  function togglePairingMode() {
    pairingMode = !pairingMode
  }

  readonly property string statusText: {
    if (paused) return "Paused"
    if (!hasDevice) return "No device connected"
    return connected ? "Connected" : "Disconnected"
  }

  readonly property string batteryText: {
    if (batteryPercent < 0) return "Battery unavailable"
    return batteryPercent + "%" + (charging ? " · Charging" : "")
  }
}
