# Changelog

All notable changes to Chiselo will be documented here.

## 0.1.6 - 2026-06-12

- Added `转为可编辑版` Layout IR v1: runtime HTML is captured after rendering into deterministic text, image, shape, pseudo-element, and whole-object fallback elements.
- Added an editable-version quality summary that reports directly editable text, replaceable images, adjustable shapes, approximated objects, whole-object fallbacks, and PPTX editability.
- Added deterministic module grouping metadata for captured cards, sections, tables, and visual modules so related text, shapes, and pseudo-elements can be identified together.
- Added module-group selection and refinement for editable versions: grouped cards/modules can be selected as one unit, nudged, aligned, snapped, duplicated, deleted, locked, moved together, and refined internally with same-width, same-height, and equal-spacing commands.
- Added a non-technical style panel pass for color swatches, text alignment, border/radius controls, shadow presets, and image display modes.
- Preserved shadow and image object-fit through direct HTML editing, editable-version capture, exported HTML, and deck schema validation.
- Added PPTX effect-risk preflight diagnostics for complex CSS visuals such as background images, radial/repeating gradients, filters, masks, clipping paths, blend modes, and 3D transforms.
- Added object-level visual diff v1 in delivery preflight so changed text, image, geometry, and key style edits can be reviewed against the original opened HTML.
- Added editability metadata for captured objects so the Inspector can distinguish directly editable text, replaceable images, adjustable shapes, approximated pseudo-elements, and whole-object iframe/canvas fallbacks.
- Reused the same page/slide boundary selectors across editable capture and export so `.slide`, `.page`, `[data-page]`, and similar document frames map more consistently.
- Added dynamic-content diagnostics for script-rendered HTML, including runtime roots, scripts, embedded pages, canvas regions, shadow components, external runtime resources, and transparent selection blockers.
- Made dynamically inserted HTML elements, images, media, and tables join the editing and delivery-check pipeline after import.
- Added editing-only transparent overlay pass-through so empty full-page hit layers no longer block selecting the real title, image, card, table, or module underneath.
- Added dynamic-content risk rows, issue icons, scoring penalties, and export guidance to make script-rendered HTML limitations visible before HTML/PDF/PPTX delivery.
- Added a script-rendered HTML compatibility regression test.
- Bumped the packaging version to `0.1.6` for the next preview build.

## 0.1.5 - 2026-06-12

- Added geometry review metrics in the Inspector: selected objects now show page/canvas margins, center offset, and a copyable geometry summary.
- Repositioned Chiselo around "HTML finishing and delivery" instead of generated-HTML-only or slide-only editing.
- Updated user-facing app labels toward page/canvas refinement, delivery preflight, object structure, and Chiselo project files.
- Bumped the packaging version to `0.1.5` for the next preview build.
- Added semantic object labels for imported HTML so the UI can show user-facing names like page, title, image, table, card, module, and cell instead of underlying tags.
- Renamed the HTML navigation UI toward object-editing language: object structure, page objects, and layer navigation.
- Added import-adapter coverage for semantic page and table-cell recognition.
- Added visual page/canvas boundary overlays with center lines and ruler ticks for direct HTML and Chiselo project editing.
- Added page/canvas frame edges and centers to direct HTML snapping so movement and resizing can align to the detected page frame.
- Added HTML multi-selection commands for matching width/height and distributing objects horizontally or vertically.
- Added an export preflight panel with HTML/PDF readiness, PPTX editability scoring, issue navigation, and format-specific review guidance.
- Added a snapshot history browser for choosing and restoring a specific `.chiselo-history/` version.

## 0.1.4 - 2026-06-11

- Added safer real-file editing: opening a local HTML or Chiselo project file creates a one-time `.chiselo-backup` sibling copy.
- Added save-time version snapshots in a sibling `.chiselo-history/` folder for HTML and Chiselo project files.
- Preserved existing `.chiselo-backup` files across app sessions instead of replacing the earliest safety copy.
- Added a toolbar shortcut to reveal the current document's backup/history folder.
- Added a confirmed restore action for the newest `.chiselo-history/` snapshot.
- Added a safe-file-history regression test to cover backup preservation and same-second snapshot ordering.

## 0.1.3 - 2026-06-10

Stability patch focused on repeatable HTML editing and generated fixture coverage.

- Made HTML image replacement refresh after image load/layout settle so selection boxes and exports stay stable.
- Made import diagnostics tolerate pages with no images, media, SVG, or tables.
- Defaulted direct HTML layout adjustments to transform mode to reduce accidental document-flow changes.
- Added generated HTML and Chiselo project fixtures plus an editing regression script that verifies text edits, image replacement, module movement, table edits, project edits, and clean export.
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
