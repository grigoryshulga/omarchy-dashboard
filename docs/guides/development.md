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

## Find the implementation

The [architecture guide](../../ARCHITECTURE.md) maps responsibilities, command
flow, persistence and plugin lifetime to their source files. Public commands
and manifest entry points stay stable when internal files move.
