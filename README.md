# Oma Connect

A starter Omarchy Quattro bar widget for a new, Omarchy-native connection app.
This first version provides the plugin manifest, a bar button, and a placeholder
panel. It does not connect to devices yet.

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
