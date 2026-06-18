# Changelog

All notable changes to Chiselo will be documented here.

## 0.1.11 - 2026-06-15

- Added a first-edit backup reminder for real local HTML and Chiselo project files so users confirm the original file backup before continuing precision edits.
- Surfaced the `.chiselo-backup` filename after opening a real file and kept save-time `.chiselo-history` snapshots in place.
- Added source-cleanliness scoring to HTML preflight and save review so export checks report whether editor-only markers or temporary edit variables would leak into the saved HTML.
- Preserved original `contenteditable` and `spellcheck` attributes while direct text editing, including clean export during an active text edit.
- Added direct HTML source-cleanliness regression coverage to release preflight.
- Added conservative stylesheet-rule writeback for unique local class rules so safe style edits can update CSS instead of adding inline style.
- Expanded stylesheet-rule writeback to safe unique selectors such as `#id`, `tag.class`, and simple descendant selectors when they only target the selected object.
- Added stylesheet writeback diagnostics and regression coverage, while shared-class edits still fall back to inline style to avoid changing multiple objects unexpectedly.
- Added one-click visual rollback for safe stylesheet-rule writeback changes, restoring the original local CSS rule instead of leaving the object edited.
- Added object-level responsive-change review so modified HTML objects inside media/container/flex/grid/sticky layout chains can be located before save or export.
- Added object-level source-writeback review so inline style edits and local CSS-rule writes can be listed and located before save or export.
- Included the exact local CSS selector in source-writeback review rows so stylesheet edits show where they landed in the original HTML source.
- Made stylesheet writeback diagnostics compare current CSS rules against the original baseline, so reverted rule edits no longer appear as active save/export changes.
- Updated source-writeback review to use the active CSS-rule diagnostic count and show selector-only rows when a rule changed without a preview object row.
- Kept direct-selection quick actions compact by default, with action buttons tucked behind an on-demand menu so selected text stays visible.
- Quieted direct-selection chrome further: selected objects now show only a small on-demand action button, object labels stay inside the menu, hover labels avoid instruction text, and object right-clicks no longer open the browser menu outside text editing.
- Reduced source-review noise for external CSS pages: external stylesheets now create a save/export review only after changed objects may actually be affected.
- Added parent, child, children-group, previous/next sibling, and same-class selection correction actions to the compact quick-action menu for nested HTML.
- Added a compact HTML path inside the quick-action menu so nested objects can jump directly to an ancestor without leaving the canvas.
- Hardened direct HTML point selection through transparent overlays so review navigation and canvas clicks keep finding the real object underneath.
- Added live undo/redo availability from the editor runtime to the macOS menu and preserved redo state across direct HTML undo restores.
- Labeled undo/redo history entries so menus and toolbar help can show the next reversible action such as text edits, object moves, image replacement, and table changes.
- Added a save-before-overwrite review prompt for real HTML files summarizing backup status, visual changes, preflight issues, and an option to open the visual review before saving.
- Added visual-change review filters for all, text, image, geometry, style, and deleted changes so preflight review can focus on the kind of edit being checked.
- Added before/after details and safe one-click rollback for revertable visual-change items, with rollback actions preserved in undo history.
- Added regression coverage for reverting newly added or duplicated HTML objects from visual-change review.
- Added safe one-click restore for deleted HTML objects when the original parent location is still available.
- Added one-click rollback buttons to source-review rows so inline style and CSS-rule writebacks can be reverted directly from export preflight.
- Added responsive-layout and source-writeback review signals so save/export preflight can flag multi-width checks and inline-style changes on stylesheet-backed HTML.
- Added breakpoint-aware responsive review hints so changed HTML objects show nearby widths to check before save or export.
- Added compact quick-action regression coverage to release preflight.
- Added visual-change rollback regression coverage to release preflight.
- Bumped the packaging version to `0.1.11` for the next preview build.

## 0.1.10 - 2026-06-13

- Added target lists for object-level visual changes so changed text, images, geometry, and style objects can be reviewed beyond the first changed object.
- Added a `视觉变更复核` card in export preflight with next/previous object navigation before HTML/PDF/PPTX delivery.
- Updated the sidebar delivery check to use the same visual-change target list for consistent object selection.
- Bumped the packaging version to `0.1.10` for the next preview build.

## 0.1.9 - 2026-06-13

- Added PPTX preflight `建议操作` repair actions for locating tables, SVG/vector objects, complex visual effects, and layered objects from the export panel.
- Added direct preflight actions for converting dynamic or whole-object HTML into an editable version and for choosing PDF when visual fidelity is the safer delivery path.
- Kept repair actions in object-facing language so users see tables, vectors, effects, layers, editable version, and PDF rather than implementation details.
- Bumped the packaging version to `0.1.9` for the next preview build.

## 0.1.8 - 2026-06-13

- Added target lists for PPTX editable-object diagnostics so text, image, shape, review, and whole-object fallback groups can be reviewed beyond the first matching object.
- Added `逐项定位` controls in the PPTX preflight report for next/previous navigation across editable objects and export-risk objects before delivery.
- Added regression coverage for multi-target PPTX review navigation and dynamic HTML whole-object fallback lists.
- Bumped the packaging version to `0.1.8` for the next preview build.

## 0.1.7 - 2026-06-13

- Added click-through targeting to the PPTX editable-object report so non-zero text, image, shape, review, and whole-object fallback counts can jump to the first matching object before export.
- Added PPTX report target IDs to HTML diagnostics and regression coverage for review-object and whole-object fallback selection.
- Reworded visible PPTX review guidance away from implementation language and toward export review actions.
- Bumped the packaging version to `0.1.7` for the next preview build.

## 0.1.6 - 2026-06-12

- Added `转为可编辑版` Layout IR v1: runtime HTML is captured after rendering into deterministic text, image, shape, pseudo-element, and whole-object fallback elements.
- Added an editable-version quality summary that reports directly editable text, replaceable images, adjustable shapes, approximated objects, whole-object fallbacks, and PPTX editability.
- Added deterministic module grouping metadata for captured cards, sections, tables, and visual modules so related text, shapes, and pseudo-elements can be identified together.
- Added module-group selection and refinement for editable versions: grouped cards/modules can be selected as one unit, nudged, aligned, snapped, duplicated, deleted, locked, moved together, and refined internally with same-width, same-height, and equal-spacing commands.
- Added a non-technical style panel pass for color swatches, text alignment, border/radius controls, shadow presets, and image display modes.
- Preserved shadow and image object-fit through direct HTML editing, editable-version capture, exported HTML, and deck schema validation.
- Added PPTX effect-risk preflight diagnostics for complex CSS visuals such as background images, radial/repeating gradients, filters, masks, clipping paths, blend modes, and 3D transforms.
- Added object-level visual diff v1 in delivery preflight so changed text, image, geometry, and key style edits can be reviewed against the original opened HTML.
- Added PPTX editable-object report v1 in delivery preflight, estimating editable text, image, shape, review, and whole-object fallback counts before export.
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
