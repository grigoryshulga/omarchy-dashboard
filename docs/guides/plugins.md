# Plugin compatibility

[← README](../../README.md) · [Controls](usage.md) · [CLI](cli.md) · [Troubleshooting](troubleshooting.md)

[Display selection](#how-a-plugin-is-displayed) · [Popout sizing](#popout-sizing) · [Launchers](#launchers-and-presentation-preferences)

## How a plugin is displayed

Dashboard selects the first available option:

1. an embedded Dashboard-side control for known non-visual services;
2. `entryPoints.dashboardPage` or a compatible `sidePanelPage`;
3. `entryPoints.dashboardWidget` — a compact, safe Widget;
4. local adaptation of the standard `KeyboardPanel`;
5. conservative window adaptation containing one directly nested `PanelWindow`
   or `FloatingWindow`;
6. a Launcher that opens a native surface or independent Dashboard popout;
7. an information tile when no safe action is available.

Dashboard never writes changes into another plugin's directory. For adaptation,
it creates a fingerprinted copy in the XDG cache. Embedded control tiles are
currently available for Stay Awake (`omarchy.idle`), Night Light, and Do Not
Disturb; they use the same public service methods as the standard Omarchy
indicators.

Launchers prefer a Dashboard popout, including when a live instance exists in
the bar. Clicking while adaptation is running opens the popout with a loading
state. Only plugins that cannot be adapted fall back to their native surface;
launching one no longer explicitly closes Dashboard.

Adaptation tries distinct `panel`, `overlay`, `barWidget`, and `menu` entry
points in that order, using one validated copy of the plugin for all attempts.
A compatible declared page wins over sibling discovery; bar wrappers may use
`Panel.qml` or one unambiguous `*Panel.qml`, including a compatible window.
Regular expressions in plugin JavaScript are preserved during adaptation.
Multiple mapped windows and `PopupWindow` still require a native launcher.

Declared `dashboardPage`, `sidePanelPage`, and `dashboardWidget` entries can
also open in a Dashboard popout when the tile is set to `Launcher`, even without
a bar instance. Hosted pages receive the shell's `manifest`, `pluginRegistry`,
`barWidgetRegistry`, and `omarchyPath` as well as settings and service context
when they declare these properties. The same values are available to
`initializeDashboard(context)`. Initialization failures are displayed in the
tile or popout.

## Popout sizing

Popouts stay inside the Dashboard surface. The Dashboard remains open and
visible around them; closing a popout, clicking outside it, or pressing Escape
returns to the Dashboard. A popout uses at most 90% of the available width and
85% of the height, even when its plugin asks for more room.

Drag the bottom-right corner to resize a popout. The size is saved separately
for each hosted plugin and survives reopening, moving the tile, and restarting
the shell. The header shows the current outer dimensions. **Auto size** clears
the saved size and restores the plugin's preferences.

Automatic sizing takes each dimension from `dashboard.popout.preferredWidth`
and `preferredHeight`, then `dashboard.preferredWidth` / `preferredHeight`,
then the original panel's intrinsic dimensions, with an 860×680 content
fallback. Adapted `KeyboardPanel` fitting helpers retain their requested
dimensions before fitting; adapted windows use their implicit dimensions.
Declared pages can provide `implicitWidth` / `implicitHeight`. The host adds
space for its header and padding. Minimum sizes are honored when the available
area permits.

Plugin authors may specify popout dimensions independently of tile dimensions:

```json
{
  "dashboard": {
    "popout": {
      "preferredWidth": 620,
      "preferredHeight": 440,
      "minWidth": 320,
      "minHeight": 240
    }
  }
}
```

For automation, set an outer size or restore automatic sizing through IPC:

```bash
omarchy-shell shell call gshulga.dashboard execute '{"type":"setPopoutSize","pluginId":"omarchy.bluetooth","size":{"width":680,"height":520}}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"setPopoutSize","pluginId":"omarchy.bluetooth","size":null}'
```

Overrides live in the host placement's `popoutSize` field in `shell.json`,
separately from the plugin's own settings. Native fallback windows are owned
by the plugin and do not use these popout size controls.

## Launchers and presentation preferences

The Launcher is a self-contained button tile: icon, name, and no implementation
details. A regular click immediately runs its action. The icon comes from an
explicit manifest field, a live bar widget, conventional `icon.svg`/`icon.png`,
a literal `icon`/`heroGlyph` in an entry point, or a semantic Nerd Font fallback.
Discovery reads only a bounded amount of data and never imports or executes
another plugin's QML.

In `edit`, a small button at the top-left of a tile cycles automatic selection,
`Embedded`, `Widget`, and `Launcher`, retaining only options that are actually
available. An arbitrary `barWidget` is not loaded automatically as a compact
Widget: it can create its own Wayland surfaces. Dashboard either adapts its
standard panel or honestly keeps the native/information fallback.

A plugin ID can occupy only one tile across the entire Dashboard. This prevents
competing IPC handlers, timers, and singleton service state. See [the architecture guide](../../ARCHITECTURE.md#plugin-loading-and-input)
for module ownership and loading behavior.
