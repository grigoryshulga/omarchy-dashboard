# Using Dashboard

[← README](../../README.md) · [CLI](cli.md) · [Plugin compatibility](plugins.md) · [Troubleshooting](troubleshooting.md)

[Shortcuts](#shortcuts) · [Tiles](#tiles) · [Spaces](#spaces) · [Text and dividers](#text-and-dividers) · [Grid](#grid-and-alignment) · [Appearance](#appearance)

## Shortcuts

Press **?** inside Dashboard for the built-in cheat sheet. To add a global
shortcut, assign `omarchy-shell shell toggle gshulga.dashboard` to a key in
your Hyprland configuration.

### Browse and interact

| Keys | Action |
| --- | --- |
| `← ↑ ↓ →` / `H J K L` | Select the nearest tile |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tile |
| `Enter` | Interact with the selected plugin |
| `Esc` | Leave interaction, then edit mode, then close Dashboard |
| `Page Up` / `Page Down` | Previous / next Space |
| `Alt+1` … `Alt+9` | Go to a Space by number |
| `Alt+E` | Toggle edit mode |
| `?` | Show shortcuts |

### Edit and place

| Keys | Action |
| --- | --- |
| `Alt++` | Open the plugin catalog |
| `Alt+V` | Toggle Framed / Glass |
| `Alt+arrow keys` / `Alt+H J K L` | Move the selected tile or graphic element |
| `Shift+arrow keys` / `Shift+H J K L` | Resize the selected tile or graphic element |
| `arrow keys` / `H J K L` | Move a new-tile preview |
| `Shift+arrow keys` / `Shift+H J K L` | Resize a new-tile preview |
| `Enter` | Add the preview tile and keep editing |
| `Delete` / `Esc` (while placing) | Discard the preview and keep editing |
| `Alt+C` / `Alt+R` | Create / rename a Space |
| `Alt+X` | Delete the current Space, with confirmation |
| `Delete` | Delete the selected tile or graphic element |

## Tiles

**Select:** hover a tile or use the navigation keys.

**Interact:** click once or press Enter. The thicker accent frame shows which
plugin receives input. The first click activates an embedded plugin; subsequent
clicks operate its controls. Launchers and system controls run their action
immediately.

**Leave:** press Esc. Hovering another tile also leaves the previous plugin's
interaction and selects the next one. Hover selection is suspended during
mouse drags, edit mode and open overlays.

**Add:** in edit mode, open the catalog with Alt++. Choose a plugin, then move
and resize its preview. Green means a valid position; red means a collision.
You can move existing tiles to make room. Press Enter or click the **+** icon
on the preview to add it. Delete, Esc or the trash icon discards the preview.
Adding or deleting a tile keeps Dashboard in edit mode.

**Move or resize:** in edit mode, drag any area of a tile or its bottom-right
handle. A preview follows the pointer while live content stays dimmed in its
original position. Tiles cannot overlap one another.

**Edit actions:** a compact row at the center of each tile lets you change its
mode, toggle its background, or delete it. Hover an icon for a tooltip. The
current display mode appears above the row, alongside the navigation number
when shortcuts are shown. **Auto** also shows the resolved mode. Small tiles
use an **…** menu with the same actions; Esc closes the menu and keeps editing.
The preview offers mode, delete and **+** actions.

**Tile background:** the square icon hides or restores Dashboard's tile fill.
The choice is saved for each tile; selection and interaction frames remain
visible. A background drawn inside the plugin itself is unchanged. See
[compatibility](plugins.md) for the available display modes.

**Popouts:** drag the bottom-right corner to set a size for that plugin.
**Auto size** restores its preferences. Closing a popout or clicking outside it
leaves Dashboard open. Native fallback windows use the plugin's own controls.

## Spaces

The active Space name appears in the header. Click the surrounding dots or use
Page Up / Page Down to switch. In edit mode, drag the dots to reorder Spaces
and double-click the active name to rename it. Deleting a Space asks for
confirmation; the last Space cannot be deleted.

Alt+1 … Alt+9 also work while an embedded plugin has focus. These shortcuts are
suspended during renaming, the catalog and popouts. A three-finger horizontal
swipe switches Spaces when the compositor forwards touch points to Dashboard.

Opening Dashboard starts loading all Spaces: the current Space first, then
the others in the background. Switching to an unfinished Space gives it
priority. Loaded plugins keep their state while Dashboard stays open; hidden
tiles do not receive input. Closing Dashboard releases these instances.

## Text and dividers

In edit mode:

- **Add Text** creates a label. Resize its frame to change the fitted font size;
  double-click to edit the text. Select it to show **left / center / right**
  alignment icons in the top bar. Alignment applies inside its existing frame.
- **Draw Divider** lets you drag a horizontal or vertical line between grid
  points. Move the whole line or stretch its round ends. Select it to show the
  **Thickness** slider in the top bar (1–16 logical pixels, default 2).

These controls replace Appearance while an element is selected. Changes appear
immediately and are saved with the element, including after moving or resizing.

Labels and dividers may overlap tiles and each other. Select one and press
Delete to remove it.

## Grid and alignment

**Grid step** sets the spacing from 5 to 80 logical pixels. It controls the
visible dots, keyboard movement, snapping and automatic placement, and is saved
with the layout.

When you change the step, existing tiles stay in place. The next keyboard move
or resize aligns the affected edge to the new grid. Mouse resizing snaps the
resulting size to the grid.

Dragging a tile, preview or text label near the canvas center shows alignment
guides. Snapping uses the nearest compatible grid line on each axis; it is
skipped when centering would move the item's origin off-grid.

The visible canvas is the placement area. It follows system spacing and keeps
the same geometry in Framed and Glass modes. Placement previews start at an
available size between the plugin's preferred and minimum dimensions.

## Appearance

Use the header's **Appearance** controls in edit mode or Alt+V:

- **Framed:** an opaque canvas with system spacing and corner radius.
- **Glass:** a transparent canvas over the desktop background.

Colors, spacing and corner radius follow Omarchy. Glass uses Hyprland's own
blur settings, including brightness, noise and vibrancy. The blur rule is
restored after a Hyprland configuration reload; corner radii update without a
Shell restart. Background dimming is a separate option.

See [README configuration](../../README.md#choose-the-appearance) for setting
names, defaults and commands, or browse the [gallery](gallery.md).
