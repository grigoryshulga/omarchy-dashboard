# Native Dashboard host prototype

This experimental branch answers one question: can Dashboard own plugin
placements through a host-scoped interface without duplicating Omarchy plugin
discovery or service lifecycle?

The prototype writes a small projection to `shell.json`:

```json
{
  "hosts": {
    "gshulga.dashboard": {
      "placements": [
        {
          "id": "acme.weather",
          "instanceId": "weather-tile",
          "slot": "main",
          "settings": {}
        }
      ]
    }
  }
}
```

Dashboard geometry remains in its XDG state document. `HostPlacements.js` owns
normalization, synchronization and settings lookup behind a small interface:

- `references(document)` projects Dashboard tiles into host references;
- `synchronize(config, hostId, references)` atomically replaces that host's
  placements and preserves instance settings;
- `entries(config, hostId)` and `settingsFor(...)` are the read interface.

Omarchy 4.0.1 does not inspect `hosts`, so `PluginRuntime` also adds third-party
plugins to the legacy `plugins[]` list. This is explicitly a compatibility
adapter, not the placement source of truth. It intentionally does not remove a
legacy entry because the current schema cannot prove whether another shell
surface still owns that reference.

Open `prototypes/native-host-logic.html` directly in a browser to run the three
guided state walkthroughs. The entire Dashboard state and shell projection are
shown after every action.

The live host projection is observable without reading configuration files:

```bash
omarchy-shell shell call gshulga.dashboard execute '{"type":"listHostEntries"}'
```

## Verdict expected from the experiment

The model is viable if live testing confirms that unknown `hosts` configuration
survives shell mutations/reloads while the compatibility entry keeps hosted
third-party services and QML Components available. Full native ownership still
requires Omarchy core to count host references in `PluginRegistry.isEnabled()`;
once it does, the `plugins[]` adapter can be deleted without changing the
Dashboard host interface.

## Placement command interface

The follow-up implementation distinguishes Pending Placement from Placed Tile
in canonical Dashboard state. The `omarchy-dashboard plugin` command pack uses
one versioned IPC request interface; installation and layout remain separate:

```bash
omarchy-dashboard plugin install URL                 # pending by default
omarchy-dashboard plugin add ID --space SPACE --auto
omarchy-dashboard plugin place ID --space SPACE --rect X,Y,W,H
omarchy-dashboard plugin move ID --space SPACE --rect X,Y,W,H
omarchy-dashboard plugin pending ID
omarchy-dashboard plugin remove ID
omarchy-dashboard space create NAME [--id STABLE_ID]
omarchy-dashboard space rename SPACE NAME
omarchy-dashboard space select SPACE
omarchy-dashboard space remove SPACE --yes
omarchy-dashboard grid set SPACING
omarchy-dashboard element add-text TEXT --space SPACE --rect X,Y,W,H [--id ID]
omarchy-dashboard element add-divider --space SPACE --line X1,Y1,X2,Y2 [--id ID]
omarchy-dashboard element list [--space SPACE]
omarchy-dashboard element remove ID
```

Pending Placement has an instance id, settings and embedding but no Space or
Rect. Placing it preserves the instance id. Exact placement is atomic and uses
the same `GridEngine` validation as Dashboard UI; the CLI never reads or writes
the state file directly.
