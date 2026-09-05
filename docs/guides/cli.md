# Command-line guide

[← README](../../README.md) · [Controls](usage.md) · [Plugin compatibility](plugins.md) · [Troubleshooting](troubleshooting.md)

[Add a plugin](#add-a-plugin) · [Exact placement](#place-a-tile-precisely) · [Commands](#common-commands) · [Help](#help-and-automation)

The CLI manages Spaces, plugins, text and dividers. Start by adding its shortcut
to `~/.local/bin` (this directory must be on your `PATH`):

```bash
mkdir -p ~/.local/bin
ln -sfn ~/.config/omarchy/plugins/gshulga.dashboard/bin/omarchy-dashboard \
  ~/.local/bin/omarchy-dashboard
```

## Add a plugin

Installing through this CLI adds the plugin to Dashboard's catalog as
**Pending placement**. It becomes a tile once you place it on a Space.
The `acme.weather` ID and repository below are examples; use your plugin's
actual ID and URL.

```bash
omarchy-dashboard plugin install https://github.com/acme/weather.git
```

The plugin appears first in the catalog with a `Pending placement` label. Open
Dashboard, press `Alt+E`, then `Alt++`, select the plugin, and place it using
the normal preview silhouette.

An installed plugin can also be sent to pending placement:

```bash
omarchy-dashboard plugin add acme.weather
```

## Place a tile precisely

When the Space and geometry are known in advance, create a tile
directly. `Rect` uses logical QML pixels in the form `X,Y,W,H` and is validated
strictly: Dashboard never shifts or shrinks it when it collides.

```bash
omarchy-dashboard plugin install https://github.com/acme/weather.git \
  --space space-main --rect 0,0,420,300

omarchy-dashboard plugin add acme.weather \
  --space space-main --rect 0,0,420,300
```

Automatic placement is enabled only explicitly:

```bash
omarchy-dashboard plugin add acme.weather --space space-main --auto
```

## Common commands

Use a Space ID or its unique name. Replace `Home` and `space-main` below
with values from `space list`. These are individual command examples.

### Spaces

```bash
omarchy-dashboard space list
omarchy-dashboard space create Work --id space-work
omarchy-dashboard space rename Work Focus
omarchy-dashboard space select Focus
omarchy-dashboard space remove Focus --yes
```

### Grid, text and dividers

```bash
omarchy-dashboard grid show
omarchy-dashboard grid set 30
omarchy-dashboard element add-text Life --space Home --rect 30,15,660,45 --id home-life-title
omarchy-dashboard element add-divider --space Home --line 30,75,690,75 --id home-life-rule
omarchy-dashboard element list --space Home
omarchy-dashboard element remove home-life-rule
```

### Plugin placement and removal

```bash
omarchy-dashboard plugin list
omarchy-dashboard plugin list --state pending --json
omarchy-dashboard plugin place acme.weather --space space-main --rect 0,0,420,300
omarchy-dashboard plugin move acme.weather --space space-work --auto
omarchy-dashboard plugin pending acme.weather
omarchy-dashboard plugin remove acme.weather
omarchy-dashboard plugin uninstall acme.weather
omarchy-dashboard plugin uninstall acme.weather --remove-placement --yes
```

## Help and automation

Use `--help` for command options, examples and exit codes:

```bash
omarchy-dashboard --help
omarchy-dashboard plugin --help
omarchy-dashboard plugin add --help
omarchy-dashboard element --help
```

`element` manages Dashboard-owned text and dividers; coordinates use the same
logical canvas pixels as `plugin --rect`. `remove` takes a plugin out of
Dashboard and keeps its installation on disk. `uninstall` removes the
code, but refuses while the plugin remains in Dashboard unless
`--remove-placement` is supplied explicitly. Every read and mutation command
supports `--json` for automation.

For direct Shell calls, see [IPC and diagnostics](troubleshooting.md#ipc-and-diagnostics).
