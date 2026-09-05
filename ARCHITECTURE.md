# Project map

Dashboard is an Omarchy Shell plugin. The manifest loads `qml/Dashboard.qml`
and `qml/BarWidget.qml`; `bin/omarchy-dashboard` is the command-line entry point.
These entry points stay stable while implementation modules are organized by
the behavior they own.

## Ownership

| Area | Main modules | Owns |
| --- | --- | --- |
| Session | `qml/Dashboard.qml` | Open/close, monitor selection, interaction mode, selection and UI actions |
| Commands | `qml/commands/DashboardManagement.qml` | Versioned requests and responses for placements, Spaces, grid and graphic elements |
| State | `qml/state/DashboardModel.js`, `DashboardStore.qml` | Document invariants, migrations, validated mutations, queued reads/writes |
| Plugins | `qml/plugins/PluginRuntime.qml` | Registry access, settings, adaptation scheduling and lifecycle injection |
| Plugin presentation | `qml/plugins/PluginPresentation.js`, `PluginControls.js`, `PluginIconResolver.js` | Presentation selection, supported service controls and icons |
| Plugin hosting | `qml/plugins/TileHost.qml`, `DashboardPopout.qml`, `HostPlacements.js` | Embedded input/lifecycle, popout sizing and Shell host references |
| Resident tiles | `qml/plugins/DashboardSessionTiles.qml`, `DashboardTileCollection.qml`, `PluginLoadOrder.js` | Prioritized background admission, session lifetime and delegate identity |
| Layout | `qml/layout/` | Grid calculations, placement previews, alignment guides and graphic elements |
| Navigation | `qml/navigation/` | Reading order, spatial selection, swipe direction and shortcut dispatch |
| Appearance | `qml/appearance/` | Surface mode normalization and applying Hyprland layer blur |
| Shared UI | `qml/ui/` | Window composition, dialogs and buttons |

Files that implement the same behavior live together even when one is pure
JavaScript and another is QML with Shell integration. Imports across areas use
explicit directory aliases such as `Plugins` or `Navigation`; JavaScript
imports name the specific module.

## State and command flow

`DashboardModel.js` is the authority for valid documents and geometry changes.
It returns candidate documents without writing files. `DashboardStore.qml`
publishes the current document and queues persistence through the bounded
reader/writer helpers in `bin/`.

UI actions enter through `Dashboard.qml`. External clients use its existing
`execute(string)` and `managePlugins(request)` endpoints. The versioned
management protocol delegates to `DashboardManagement.execute(request)`, which
depends on an injected store, plugin runtime and canvas dimensions. It can run
and be tested without creating a window or connecting to a plugin registry.
Its Space, graphic-element and placement handlers are internal implementation.

For changes that affect Shell host references, the candidate is built first,
then `PluginRuntime.applyHostPlacementTransaction` updates Shell configuration.
Only after that succeeds does the store publish the document and flush it.
Management returns a failure if the host transaction or document staging fails;
the tests check that later steps are not called after a failure. UI host
mutations follow the same ordering in `Dashboard.commitHostMutation`.

The JSON document format, manifest entry points and executable commands are
independent of the internal QML directory layout.

## Plugin loading and input

`PluginPresentation.js` resolves declared capabilities and presentation
preferences. `PluginRuntime.qml` supplies registry/settings context and runs
bounded adaptation helpers when a standard Omarchy panel needs an embedded
host. `qml/plugins/adapters/` contains the self-contained QML hosts copied into
the adapted artifact; they must not depend on other Dashboard directories.

The Dashboard surface owns one session collection. `PluginLoadOrder` orders
all tiles with the active Space first; the adapter scheduler uses that order
before starting each job. `DashboardSessionTiles` admits the active Space
immediately and then admits one background tile at a time after existing loads
settle. A Space switch bypasses background admission without discarding work
already started. `TileHost.loadSettled` reports completion or failure; controls
and launchers need no page Loader and settle immediately. A short timer yields
between background admissions and stops when Dashboard closes.

`DashboardTileCollection` reconciles by tile ID, so moving or reprioritizing
a tile does not recreate its Loader. `TileHost` separates `keepLoaded` from
`surfaceActive`: a hidden page can remain resident while input is disabled.
Closing Dashboard empties the collection and releases its pages. Adaptation
artifacts remain reusable in the disk cache.

`TileHost` handles hover selection, entering interaction with one click, and
the thicker interaction frame. `DashboardPopout` owns its separate loaded page
and resize behavior; `PopoutGeometry.js` resolves saved, declared and intrinsic
size hints within the available area. Shared Shell services and bar widgets
remain owned by Shell.

## Python and process entry points

The three Python implementations already have distinct responsibilities:

- `lib/omarchy_dashboard_cli.py`: argument parsing, IPC requests and output.
- `lib/omarchy_dashboard_adapter.py`: QML analysis/transformation and secure
  publication of cached plugin artifacts.
- `lib/omarchy_dashboard_icons.py`: bounded icon discovery from installed plugins.

`bin/` contains their executable entry points plus standalone state I/O and
bounded-process helpers. The standalone helpers intentionally use isolated
Python execution. Keep that contract when changing process invocation or paths.

## Verification map

Run `bash tests/all.sh` for the complete suite. QML tests are grouped by the
behavior they exercise:

| Test | Coverage |
| --- | --- |
| `tst_DashboardModel.qml` | State invariants, mutations, migrations and serialization |
| `tst_DashboardManagement.qml` | Management protocol, queries, transaction order and failures |
| `tst_GridEngine.qml` | Bounds, collisions, snapping and available placement geometry |
| `tst_Navigation.qml` | Reading order, spatial selection, gestures and shortcuts |
| `tst_Appearance.qml` | Surface modes and blur rule generation |
| `tst_PluginCompatibility.qml` | Capabilities, controls, icons, size hints and collection identity |
| `tst_DashboardSession.qml` | Background preloading, retained state, errors, edits and teardown |
| `tst_PluginLoadQueue.qml` | Foreground priority, bounded background admission and queue lifetime |
| `tst_TilePointer.qml` | Mouse selection, interaction, focus and Escape |
| `tst_ElementStyleControls.qml` | Contextual alignment/thickness controls, rendering and persisted styles |
| `tst_PlacementActions.qml` | Silhouette actions, compact controls, tooltips and drag handling |
| `tst_DashboardPopout.qml` | Dismissal, resizing and initialization recovery |

Python tests cover CLI behavior, adaptation, icons and secure helpers.
`tests/adapter-smoke.sh` adapts installed Omarchy panels using a temporary cache.
`tests/live-corner-radius.sh` is a separate live-system check. Tests that require
Shell or real plugins are kept outside the pure model tests.

After a successful full suite, validate the installed plugin and restart Shell.
Read-only CLI queries then verify the installed command wiring without changing
the user's layout.
