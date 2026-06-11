# Changelog

All notable changes to Chiselo will be documented here.

## Unreleased

- Added semantic object labels for imported HTML so the UI can show user-facing names like page, title, image, table, card, module, and cell instead of raw DOM tags.
- Renamed the HTML navigation UI toward object-editing language: object structure, page objects, and layer navigation.
- Added import-adapter coverage for semantic page and table-cell recognition.
- Added visual page/slide boundary overlays with center lines and ruler ticks for direct HTML and deck editing.
- Added page/slide frame edges and centers to direct HTML snapping so movement and resizing can align to the detected page frame.
- Added HTML multi-selection commands for matching width/height and distributing objects horizontally or vertically.
- Added an export preflight panel with HTML/PDF readiness, PPTX editability scoring, issue navigation, and format-specific review guidance.
- Added a snapshot history browser for choosing and restoring a specific `.chiselo-history/` version.

## 0.1.4 - 2026-06-11

- Added safer real-file editing: opening a local HTML/deck file creates a one-time `.chiselo-backup` sibling copy.
- Added save-time version snapshots in a sibling `.chiselo-history/` folder for HTML and deck files.
- Preserved existing `.chiselo-backup` files across app sessions instead of replacing the earliest safety copy.
- Added a toolbar shortcut to reveal the current document's backup/history folder.
- Added a confirmed restore action for the newest `.chiselo-history/` snapshot.
- Added a safe-file-history regression test to cover backup preservation and same-second snapshot ordering.

## 0.1.3 - 2026-06-10

Stability patch focused on repeatable HTML editing and generated fixture coverage.

- Made HTML image replacement refresh after image load/layout settle so selection boxes and exports stay stable.
- Made import diagnostics tolerate pages with no images, media, SVG, or tables.
- Defaulted direct HTML layout adjustments to transform mode to reduce accidental document-flow changes.
- Added generated HTML and `.aislide` fixtures plus an editing regression script that verifies text edits, image replacement, module movement, table edits, deck edits, and clean export.
- Updated release and packaging docs for the `0.1.3` preview release.

## 0.1.2 - 2026-06-10

Patch preview update focused on first-install guidance for non-technical users.

- Added a dedicated `首次打开帮助.txt` file into the DMG package.
- Expanded first-launch troubleshooting for blocked, unverified, and “move to trash” macOS alerts.
- Documented `Open Anyway`, Finder right-click `Open`, and quarantine removal steps.
- Updated packaging and publishing docs for the `0.1.2` preview release.

## 0.1.1 - 2026-06-10

Patch preview update focused on repository polish, HTML editing stability, and issue navigation.

- Reorganized the app source into a top-level `Chiselo/` folder for a cleaner public GitHub layout.
- Fixed CI paths after repository cleanup.
- Locked typography during HTML text editing and forced plain-text paste to avoid accidental font mismatches.
- Made delivery-check summary rows clickable so resource, table, SVG, overflow, bounds, and overlap warnings can jump to the related HTML element.
- Updated packaging and publishing docs for the `0.1.1` preview release.

## 0.1.0 - 2026-06-08

Initial public preview preparation.

- Renamed the project to Chiselo.
- Added the slogan "Chisel your HTML".
- Added native macOS app packaging as `Chiselo.app`.
- Added drag-to-Applications DMG packaging.
- Added direct HTML editing with click selection, drag, resize, text editing, zoom, table/image tools, and export.
- Added high-fidelity PDF export.
- Added best-effort object-editable PPTX export.
- Added AI layout skills for Codex and Claude.
- Added smoke, interaction, precision, import adapter, visual QA, and export scripts.
- Added source-available non-commercial license and GitHub-ready documentation.
- Added first-preview release notes and a step-by-step GitHub publishing guide.
- Added GitHub repository copy, creator note, discovery keywords, and star reminder.
- Added a saved GitHub update workflow and reusable push script.
- Configured the update push script to use `~/.gh` for GitHub CLI state.
- Added stronger GitHub search keywords for HTML editing and html2ppt/html2pptx queries.
- Cleaned the public repository structure by moving screenshots to `assets/`, moving schema validation to `scripts/`, and removing AI prompt skill folders from the root.
- Reorganized the app source into a top-level `Chiselo/` folder for a cleaner public GitHub layout.
- Fixed CI paths after repository cleanup.
- Locked typography during HTML text editing and forced plain-text paste to avoid accidental font mismatches.
- Made delivery-check summary rows clickable so resource, table, SVG, overflow, bounds, and overlap warnings can jump to the related HTML element.
