# Dashboard Plugin Hosting

This context describes how an installed Omarchy plugin becomes owned and
positioned by Dashboard without conflating code installation with visual layout.

## Language

**Plugin Installation**:
Plugin code and its manifest available to Omarchy on disk. It does not imply that Dashboard owns or displays the plugin.
_Avoid_: Installed tile, enabled placement

**Host Placement**:
Dashboard's durable ownership record for one Plugin Installation. It is either a Pending Placement or a Placed Tile.
_Avoid_: Enabled plugin, dashboard plugin

**Pending Placement**:
A Host Placement that has no Space or Rect and awaits manual or commanded placement.
_Avoid_: Draft, unplaced tile, queue item

**Placed Tile**:
A Host Placement with one Space and one valid Rect.
_Avoid_: Widget instance, positioned plugin

**Space**:
A named Dashboard canvas identified by a stable id.
_Avoid_: Page, workspace, tab

**Rect**:
A Placed Tile's exact logical-pixel geometry within a Space, expressed as `x`, `y`, `w`, and `h`.
_Avoid_: Grid cells, bounds
