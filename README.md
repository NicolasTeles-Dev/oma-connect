# Oma Connect

A starter Omarchy Quattro bar widget for a new, Omarchy-native connection app.
The first UI slice provides a compact Oma icon bar button, a lifecycle-safe
panel, and an explicit connection status boundary. It does not connect to
devices yet.

## Install for development

Copy or clone this directory into:

```sh
~/.config/omarchy/plugins/io.github.nicolas.oma-connect
```

Then validate and refresh plugin discovery:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.nicolas.oma-connect
omarchy-shell shell rescanPlugins
```

Enable and position the widget with the Omarchy plugin and bar commands for your
installed version. The plugin requires the Omarchy Quattro shell runtime.

## Planned next step

Build the dedicated Omarchy connection app and then connect this widget to it.
This project is not based on or dependent on KDE Connect. No external services,
privileged commands, or extra dependencies are used by this scaffold.

The intended architecture is:

```text
Flutter mobile app -> connection service -> Panel.qml
```

The bar and panel already expose the lifecycle methods Omarchy expects. The
connection state is currently local to the UI so the transport can be designed
without rewriting the plugin shell.

`service/` contains the Linux-side discovery service distributed with the
plugin. `DeviceModel.qml` defines the first device data contract. Set `demoMode` to
`true` to preview the temporary `Oma Demo` fixture while styling the connected
state. It defaults to `false` so the pairing screen is the normal empty state.

When pairing mode is enabled, the bar panel starts the bundled Node service
automatically. A paired device keeps the service running so heartbeat updates
continue after pairing mode is turned off.

When no device is available, the panel shows a pairing mode switch. It currently
changes local UI state only; the future connection service will use that state
to start and stop discovery.
