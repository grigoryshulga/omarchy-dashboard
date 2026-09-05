# Troubleshooting and diagnostics

[← README](../../README.md) · [Controls](usage.md) · [CLI](cli.md) · [Plugin compatibility](plugins.md)

[Quick fixes](#quick-fixes) · [Saved data](#saved-data) · [Loading and cache](#loading-and-cache) · [IPC](#ipc-and-diagnostics)

## Quick fixes

| Symptom | Try |
| --- | --- |
| No Dashboard button in the bar | Run `omarchy plugin enable gshulga.dashboard --section left`. |
| Changes are not visible after a local update | Run `omarchy restart shell`. |
| A plugin opens as a launcher | Check [supported presentations](plugins.md); some windows need their native surface. |
| A popout is too large or small | Resize its bottom-right corner, or choose **Auto size** to restore the plugin's preferences. |
| A plugin has no compact widget option | An ordinary bar widget is not necessarily safe to embed. See [compatibility](plugins.md). |
| A layout command fails | Read its error with `--json`; check Space names, canvas bounds and collisions with `omarchy-dashboard grid show` and `omarchy-dashboard plugin list`. |

## Saved data

| Data | Default location |
| --- | --- |
| Layout: Spaces, tiles and graphic elements | `~/.local/state/omarchy/gshulga.dashboard.json` |
| Adapted plugin cache | `~/.cache/omarchy-dashboard` |
| Widget settings and per-plugin popout sizes | `~/.config/omarchy/shell.json` |

`XDG_STATE_HOME` and `XDG_CACHE_HOME` override the first two base directories.
Back up the layout file to keep your arrangement. For a manual restore, stop
Shell first so its in-memory document cannot overwrite your changes.

Removing Dashboard leaves hosted plugin installations and saved layout data on
disk. If you added the optional CLI symlink from the [CLI guide](cli.md), remove
that shortcut after uninstalling:

```bash
unlink ~/.local/bin/omarchy-dashboard
```

## Loading and cache

Embedded plugin pages and widgets load when their Space is first visited.
Switching Spaces hides them and suspends their input, while retaining the same
QML instances, local state, and lifecycle. Returning to a Space does not
initialize its plugins again. A single Dashboard window owns these instances,
so summoning Dashboard on another monitor also preserves them.

New plugins on hidden Spaces remain unloaded until that Space is visited.
Moving or reordering an existing tile preserves its instance; removing a tile
or Space releases the affected instances. Closing Dashboard releases all its
tile instances, and the next opening starts a fresh lazy session. Changing a
plugin's presentation or reloading its code can still replace its page.
Shared services and bar widgets remain owned by Omarchy Shell.

Source plugin directories are never changed. The cache is content-fingerprint
addressed, created through a staging directory, and validated before reuse.
Version-control metadata directories (`.git`, `.hg`, `.svn`) are not copied into
the runtime cache. Plugin assets may be up to 8 MiB per file, with a 16 MiB
limit for the entire tree; the entry point remains limited to 1 MiB. This
includes larger preview images without omitting assets a plugin may use.
Adaptation runs serially for visible tiles, skips Dashboard service controls,
and discards results from an obsolete registry generation after a plugin update.
State is limited to 256 KiB, read without following symlinks,
and saved atomically.

## IPC and diagnostics

`status` is available directly:

```bash
omarchy-shell shell call gshulga.dashboard status x
```

Complex operations are passed as one JSON argument through `execute`:

```bash
omarchy-shell shell call gshulga.dashboard execute '{"type":"getState"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"listHostEntries"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"addSpace","name":"Work"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"addPlugin","pluginId":"omarchy.network"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"setTileEmbedding","embedding":"launcher"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"setMode","mode":"edit"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"setGridSpacing","value":20}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"addText","text":"System status"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"addDivider","x1":0,"y1":100,"x2":600,"y2":100}'
```

Supported operations are `status`, `getState`, `listPlugins`, `listHostEntries`,
`open`, `close`, `toggle`, `setPopoutSize`, `selectSpace`, `nextSpace`, `addSpace`,
`renameSpace`, `removeSpace`, `addPlugin`, `selectTile`, `removeTile`,
`moveTile`, `resizeTile`, `placeTile`, `activateTile`, `setTileEmbedding`,
`addText`, `updateText`, `addDivider`, `placeElement`, `removeElement`,
`setGridSpacing`, `reorderSpace`, and `setMode`. All layout commands use the
same validation as the UI.
