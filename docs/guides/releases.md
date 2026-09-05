# Releasing Dashboard

[← README](../../README.md) · [Changelog](../../CHANGELOG.md) · [Development](development.md)

## The three stages

- **dev:** ongoing changes and testing. Push completed work here.
- **Draft PR from dev to main:** a reviewable candidate; it does not release anything.
- **main + version tag + GitHub Release:** the tested version users install.

A push to `main` affects Git-based plugin updates even before a GitHub Release
is published. Merge only when the candidate is ready. Use a **merge commit**
for the release PR so `dev` and `main` retain shared history.

## Prepare a candidate

1. Choose a version. Use a patch for fixes, a minor version for compatible
   features, and a major version for breaking changes. The current candidate is **1.8.0**.
2. Update `manifest.json`, the pending section in `CHANGELOG.md`, and
   `docs/releases/1.8.0.md`. While the PR is a draft, keep the changelog marked
   Unreleased and the notes marked as a draft.
3. Run the complete local checks on Omarchy:

   ```bash
   QT_QPA_PLATFORM=offscreen bash tests/all.sh
   ```

4. Install, validate and restart using the [development guide](development.md#install-a-local-checkout).
5. Push `dev`, then open or update its draft PR against `main`.

GitHub's **QML and Python** check runs in an Arch Linux container. It does not
replace the local installed-panel smoke tests, plugin validation or live UI check.

## Check the release candidate

Use an ordinary saved layout and a temporary test Space for new placements:

- Open Dashboard, switch Spaces quickly, and return to a loaded plugin.
- Interact with an embedded plugin; leave it using Esc and hover selection.
- Open, resize and close a popout; confirm Dashboard remains open around it.
- Add a plugin with Enter, discard another preview with Delete, and try a small tile's menu.
- Toggle a tile background and check its selected and unselected outlines.
- Edit text inline; save and cancel. Change alignment and divider thickness.
- Close and reopen Dashboard; confirm saved placement and appearance choices.

Remove the temporary Space when finished. Record any failing plugin and steps
in the PR. Treat known limitations explicitly rather than claiming universal compatibility.

## Publish when ready

These are release actions, performed only after deciding to publish:

1. Set the actual release date in the changelog, remove the draft sentence from
   the release notes, and change its compare link to end at `v1.8.0`.
2. Run the checks again, commit the final metadata to `dev`, push, and wait for green CI.
3. Mark the PR ready, review the diff, and merge it into `main` using a merge commit.
4. Fetch the merged branch and tag that exact commit:

   ```bash
   git fetch origin
   git show origin/main:manifest.json
   git tag -a v1.8.0 origin/main -m "Dashboard 1.8.0"
   git push origin v1.8.0
   gh release create v1.8.0 --verify-tag --title "Dashboard 1.8.0" \
     --notes-file docs/releases/1.8.0.md
   ```

   The manifest version must be `1.8.0`. Never move or overwrite a published tag.
   The notes file must contain the final reviewed text.
5. Bring `dev` forward to include the merge commit:

   ```bash
   git switch dev
   git merge --ff-only origin/main
   git push origin dev
   ```

For later releases, replace the version and notes path in these instructions.
If a release needs a fix, prepare a patch release through the same process.
