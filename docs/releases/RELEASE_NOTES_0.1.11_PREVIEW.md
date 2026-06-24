# Chiselo 0.1.11 Preview

Chiselo is a native macOS app for visually refining existing HTML files. It is focused on modifying HTML you already have, not building websites from scratch.

## Highlights

- Added a first-edit reminder to confirm the original file backup before continuing changes.
- Shows the prepared `.chiselo-backup` filename after opening a real local HTML or Chiselo project file.
- Keeps save-time `.chiselo-history/` snapshots before overwriting an existing file.
- Keeps selected-object quick actions compact by default so the toolbar no longer covers the text being edited.
- Adds release-preflight coverage for the compact selection quick-action UI.

## Safety Notes

When opening a real local file, Chiselo keeps a sibling backup such as:

`filename.chiselo-backup.html`

Before saving over an existing file, Chiselo also writes a timestamped snapshot into:

`.chiselo-history/`

For important delivery files, keep both the original source and Chiselo's backup/history files until you have reviewed the final export.

## Install

Download `Chiselo-0.1.11.dmg` after the GitHub Release asset is published.

This build is signed with Developer ID, notarized by Apple, and stapled for Gatekeeper verification.
