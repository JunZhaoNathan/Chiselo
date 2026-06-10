# Changelog

All notable changes to Chiselo will be documented here.

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
