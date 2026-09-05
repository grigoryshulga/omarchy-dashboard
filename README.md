# Omarchy Dashboard

Your Omarchy plugins in one place: arrange them as tiles, group them into
Spaces, and work with the mouse or keyboard.

**[Install](#install) · [Configure](#configure) · [Uninstall](#uninstall) · [Guides](#guides)**

![Dashboard in Glass mode with the Tokyo Night theme](preview.png)

## Install

Requires Omarchy with Omarchy Shell and its plugin commands.

```bash
omarchy plugin add https://github.com/grigoryshulga/omarchy-dashboard.git --enable
```

If the bar button does not appear:

```bash
omarchy plugin enable gshulga.dashboard --section left
```

Click the Dashboard button to open it, or run:

```bash
omarchy-shell shell toggle gshulga.dashboard
```

To update a Git installation:

```bash
omarchy plugin update gshulga.dashboard
```

## Configure

### Arrange your workspace

1. Press **Alt+E** to enter edit mode.
2. Press **Alt++** to open the catalog and choose an installed plugin.
3. Move the preview, then press **Enter** or its **+** icon to add it.
   **Del** or the trash icon removes it; you stay in edit mode.
4. Drag tiles to move them; use the bottom-right handle to resize. Adjust
   **Grid step** at the bottom-right of the canvas for finer or coarser placement.
5. Press **Alt+C** to create another Space, or double-click its name to rename it.
6. Press **Alt+E** again when finished. Changes are saved automatically.

Hover a tile to select it. Click once to enter interaction: a thicker frame
marks the active plugin. **Esc** leaves interaction; **?** shows all shortcuts.
Use **Page Up / Page Down** to switch Spaces.

### Choose the appearance

In edit mode, use **Appearance** in the header or press **Alt+V** to switch
between an opaque **Framed** canvas and transparent **Glass**. Colors follow
your Omarchy theme.

Use `omarchy bar set gshulga.dashboard <key> <value>` to change these options.
For `true` / `false` values, add `--json`:

| Key | What it changes | Values | Default |
| --- | --- | --- | --- |
| `surfaceMode` | Canvas appearance | `Glass`, `Framed` | `Glass` |
| `dimBackground` | Dim the background | `true`, `false` | `true` |
| `blurBackground` | Use system blur in Glass mode | `true`, `false` | `true` |
| `showLabel` | Show “Dashboard” beside the bar icon | `true`, `false` | `false` |

For example:

```bash
omarchy bar set gshulga.dashboard surfaceMode Framed
omarchy bar set gshulga.dashboard showLabel true --json
```

### Resize a popout

Drag its bottom-right corner. Dashboard remembers the size for that plugin;
**Auto size** restores the plugin's preferred dimensions. Close the popout,
click outside it, or press **Esc** to return to Dashboard.

## Uninstall

```bash
omarchy plugin remove gshulga.dashboard
```

Confirm removal when prompted. Hosted plugins and your saved layout remain on
disk. See [saved data and optional CLI cleanup](docs/guides/troubleshooting.md#saved-data).

## Guides

| I want to… | Read |
| --- | --- |
| Learn shortcuts, edit tiles, add text or dividers | [Using Dashboard](docs/guides/usage.md) |
| Install and place plugins from the terminal | [CLI guide](docs/guides/cli.md) |
| Understand supported plugins and popout sizing | [Plugin compatibility](docs/guides/plugins.md) |
| Fix a problem or find saved data | [Troubleshooting](docs/guides/troubleshooting.md) |
| See more themes and layouts | [Gallery](docs/guides/gallery.md) |
| Work on the code | [Development](docs/guides/development.md) · [Architecture](ARCHITECTURE.md) |
