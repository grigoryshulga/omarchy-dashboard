# Changelog

User-visible changes are grouped by release. A version marked **Unreleased**
is being tested on `dev`; `main` is the stable installation branch.

## [1.8.1] — Unreleased

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

[1.8.1]: https://github.com/grigoryshulga/omarchy-dashboard/compare/v1.8.0...dev
[1.8.0]: https://github.com/grigoryshulga/omarchy-dashboard/compare/dfb7f4c...v1.8.0
