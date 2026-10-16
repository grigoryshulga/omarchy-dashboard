# Changelog

User-visible changes are grouped by release. A version marked **Unreleased**
is being tested on `dev`; `main` is the stable installation branch.

## [1.8.6] — 2026-10-16

### Fixed

- Keep Dashboard working when an Omarchy update changes the system values it
  reads. Colors, borders, spacing, and fonts now come from one place with
  built-in fallbacks, so a token that was renamed or removed leaves a readable
  surface instead of a broken binding. Previously a missing nested token such as
  `Color.popups.border` or `Style.font.subtitle` raised `Unable to assign
  [undefined]` and the affected dialogs, popouts, and tiles lost their colors.
- Read the focused monitor, the environment, and the screen list through that
  same place, and load the Hyprland and `hyprctl` pieces behind their own
  loaders. A module or tool that is unavailable now degrades — no focused
  monitor, no background blur — instead of failing Dashboard as a whole.
- Popup, dialog, and card outlines follow the shell's `normalBorderWidth`
  instead of a fixed 1 pixel, so themes that drop or thicken control borders
  apply to Dashboard too.

### Development

- Add `qml/system/`, the single seam between Dashboard and the host shell:
  `HostChrome` for visual tokens, `HostSession` for session resources, and a
  pure normalization library holding the fallback table.
- Add `tests/qml/tst_HostChrome.qml` for the fallbacks against an incomplete
  shell, and `tests/live-system-seam.sh` — a live check that resolves the seam
  against the installed shell modules and fails when a Dashboard file leaks a
  binding error. Both are documented in the architecture and development guides.

## [1.8.5] — 2026-10-14

### Fixed

- Load embedded plugins again on Omarchy builds whose `omarchy-shell` answers
  over its own socket (Omarchy 4.0.4+). The plugin-list helper ran with a
  hard-coded `OMARCHY_PATH=/usr/share/omarchy`, so against a shell running from
  any other path — a dev checkout, a custom install — the helper could not
  reach the live shell, the catalog came back empty and no tile content
  loaded. Helpers now inherit the live session values (`OMARCHY_PATH`,
  `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`) with the packaged path as fallback.

### Development

- Cover the helper-environment builder with unit tests and pin the bounded
  helper contract against the live-environment wiring.

## [1.8.4] — 2026-10-14

### Fixed

- Render Dashboard again on Omarchy installs updated to Qt 6.12 (quickshell
  0.3.2). Qt 6.12 ships its own `Color` type that shadowed the palette
  singleton, leaving tiles, dialogs and controls without colors. Every palette
  reference is now qualified as `Commons.Color`, matching the Shell's own
  migration.
- Lay out the grid canvas reliably on first open. Qt 6.12 evaluates dependent
  bindings eagerly, which turned the canvas-bounds feedback into a detected
  binding loop and broke the initial sizing; canvas bounds now commit once per
  layout pass.
- Disable the `ShellIpc` handlers that current Omarchy panels declare, so
  embedded copies of updated panels such as Bluetooth render without trying to
  own the IPC target the bar panel already serves.

### Development

- Add an adapter regression test for the `ShellIpc` wrapper.

## [1.8.3] — 2026-09-20

### Fixed

- Choose the Framed or Glass surface again. Dashboard saves its own bar settings
  through the scoped Shell API instead of the host registry, which third-party
  plugins no longer receive.
- Keep the shown surface mode in sync with the saved configuration, so switching
  to Glass (or back to Framed) always applies and never leaves a stale value.
- Preserve the other appearance choices when one option changes, so switching
  the surface mode no longer drops the saved background preferences.

### Changed

- Open Dashboard faster by reusing validated plugin adaptations when the
  installed plugins are unchanged, and refresh the plugin catalog on each open
  instead of waiting for registry signals the scoped API does not expose.

### Development

- Add regression tests for the Dashboard settings helpers.

## [1.8.2] — 2026-09-11

### Fixed

- Restore plugin catalog discovery on Omarchy 4.0.3 by combining Shell's public
  plugin list with the public manifest catalog.
- Keep catalog helpers working when Dashboard launches them with a clean process
  environment.

## [1.8.1] — 2026-09-05

### Fixed

- Stop repeatedly saving an unchanged layout after a successful write. New edits
  made during a write still save, and failed writes retain their retry behavior.

### Changed

- Remove obsolete text-editor state and unused persistence configuration without
  changing the text creation or inline editing controls.

### Development

- Add real Quickshell regression checks for idle saves, edits during writes and
  recovery after a failed write. Install Quickshell in GitHub Actions to run them.

## [1.8.0] — 2026-09-05

### Added

- Background preloading across all Spaces, with priority for the current Space.
  Loaded plugin instances and their state remain in memory until Dashboard closes.
- Resizable popouts that keep Dashboard visible, remember per-plugin dimensions,
  and support restoring preferred sizes with **Auto size**.
- Per-tile background toggles. Transparent tiles show their outline only when selected.
- Text alignment and divider thickness controls in the top bar.
- Inline text editing: double-click a label, save with Enter or a click outside,
  and cancel with Esc.

### Changed

- Hover selects a plugin; one click enters interaction. A thicker frame identifies
  the active plugin without an extra status badge.
- Adding plugins uses controls on the placement preview. Enter adds and Delete
  discards the preview while keeping edit mode active.
- Tile editing uses icon actions with tooltips and a visible display-mode label.
  Small tiles collapse their actions into an **…** menu.
- Tiles and placement previews can be resized from every edge and corner.
  Small launchers and service controls use compact icon layouts.
- Plugin adaptation supports more existing Omarchy panels, sibling entry points,
  shared services, size hints, and larger asset files.
- README now focuses on installation, configuration and removal; detailed guides
  and an architecture map live separately.

### Fixed

- Dashboard keyboard focus after opening and switching interaction targets.
- Overlapping shortcut numbers and tile editing controls.
- Plugin state loss when switching Spaces or moving retained tiles.
- Background queues being blocked by failed pages or service readiness.
- Persistence and helper handling: bounded input/output, atomic state writes,
  safer paths, timeouts and stale adaptation-result handling.

### Development

- Modules and tests are organized by responsibility.
- GitHub Actions runs QML and Python checks for `dev` and `main`.
  Installed-panel smoke tests and Shell validation run locally on Omarchy.

## 1.7.0 — Existing main baseline

The repository already reported version 1.7.0 before release tracking began.
There was no corresponding GitHub Release or tag. This entry records that
baseline without assigning a retrospective release date.

[1.8.1]: https://github.com/grigoryshulga/omarchy-dashboard/compare/v1.8.0...v1.8.1
[1.8.2]: https://github.com/grigoryshulga/omarchy-dashboard/compare/v1.8.1...v1.8.2
[1.8.3]: https://github.com/grigoryshulga/omarchy-dashboard/compare/v1.8.2...v1.8.3
[1.8.4]: https://github.com/grigoryshulga/omarchy-dashboard/compare/v1.8.3...v1.8.4
[1.8.5]: https://github.com/grigoryshulga/omarchy-dashboard/compare/v1.8.4...v1.8.5
[1.8.6]: https://github.com/grigoryshulga/omarchy-dashboard/compare/v1.8.5...v1.8.6
[1.8.0]: https://github.com/grigoryshulga/omarchy-dashboard/compare/dfb7f4c...v1.8.0
