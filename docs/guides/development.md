# Development

[← README](../../README.md) · [Architecture](../../ARCHITECTURE.md) · [Diagnostics](troubleshooting.md)

Develop on `dev`; prepare stable updates through a PR into `main`. See the
[release guide](releases.md) for versioning, testing and publishing.

## Run the checks

From the repository root:

```bash
bash tests/all.sh
```

The suite covers QML behavior, the management protocol, CLI and secure Python
helpers. It also adapts real installed Omarchy panels and validates the plugin
manifest. It requires Omarchy Shell's files, Python 3 and Qt 6 `qmltestrunner`.
See the [verification map](../../ARCHITECTURE.md#verification-map) to find tests
for a particular area.

## Install a local checkout

After the checks pass, run these commands from the repository root. `rsync`
replaces the installed plugin copy with the checkout contents:

```bash
mkdir -p ~/.config/omarchy/plugins/gshulga.dashboard
rsync -a --delete --exclude '.git/' ./ ~/.config/omarchy/plugins/gshulga.dashboard/
omarchy plugin validate ~/.config/omarchy/plugins/gshulga.dashboard
omarchy plugin enable gshulga.dashboard --section left
omarchy restart shell
```

Check that the installed copy responds:

```bash
omarchy-shell shell call gshulga.dashboard status x
```

## Check live system styling

With Hyprland and Omarchy Shell running:

```bash
bash tests/live-corner-radius.sh
```

This check temporarily changes the effective rounding, checks the response to
`configreloaded`, and restores the original value.

## Check the system seam

The plugin reads colors, borders, spacing and fonts from the installed shell
through `qml/system/`. Run the seam check after updating Omarchy, before
trusting the UI:

```bash
bash tests/live-system-seam.sh
```

It loads `HostChrome`, `HostSession` and a few migrated components against the
*installed* `qs.Commons` and `qs.Ui` (not the test fixture) and fails if any of
them leaks a binding error. It needs no compositor and changes nothing. When a
token is renamed or removed, the check still passes and the printed values show
the built-in fallbacks — that is the point.

## Find the implementation

The [architecture guide](../../ARCHITECTURE.md) maps responsibilities, command
flow, persistence and plugin lifetime to their source files. Public commands
and manifest entry points stay stable when internal files move.
