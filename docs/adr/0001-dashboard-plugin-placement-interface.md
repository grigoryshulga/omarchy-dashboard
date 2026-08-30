# Use pending-by-default host placements with Dashboard-owned geometry

Dashboard CLI commands distinguish Plugin Installation from Host Placement and
create a Pending Placement by default. Callers may instead request a Placed Tile
with a Space plus either an exact Rect or explicit auto-placement, but Dashboard
alone validates and mutates geometry through one versioned IPC interface. This
keeps installation safe and predictable, prevents CLI and UI layout rules from
diverging, and preserves exact reproducible placement for automation.

## Considered options

- A minimal `put/list/remove` interface was deeper but made install, move and
  pending transitions difficult to discover.
- Auto-placement by default was convenient but allowed installation to make an
  arbitrary visual decision without knowing the user's intended Space.
- Editing the Dashboard state file from the CLI was rejected because it would
  create a second owner for collision, bounds and migration rules.

## Consequences

The CLI uses explicit `install`, `add`, `place`, `move`, `pending`, and `remove`
verbs. Exact placement is atomic and never silently snapped or relocated.
