import QtQuick

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

  function togglePairingMode() {
    pairingMode = !pairingMode
  }

  readonly property string statusText: {
    if (!hasDevice) return "No device connected"
    return connected ? "Connected" : "Disconnected"
  }

  readonly property string batteryText: {
    if (batteryPercent < 0) return "Battery unavailable"
    return batteryPercent + "%" + (charging ? " · Charging" : "")
  }
}
