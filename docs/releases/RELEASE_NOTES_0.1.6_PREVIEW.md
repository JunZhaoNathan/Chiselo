# Chiselo 0.1.6 Preview

Chiselo is a native macOS app for high-fidelity refinement and delivery of existing HTML files.

中文：Chiselo 是一款 HTML 精修与交付工具。打开已有 HTML 页面/文档，精修文字、图片、表格、模块和版式，交付前预检问题，然后导出干净 HTML、高保真 PDF 或尽量可编辑的 PPTX。

## What Changed In 0.1.6

- Added dynamic-content compatibility diagnostics for script-rendered and complex HTML.
- Added `转为可编辑版` Layout IR v1 for turning rendered HTML into deterministic editable text, image, shape, pseudo-element, and whole-object fallback elements.
- Shows a quality summary for editable versions, including editable text, replaceable images, adjustable shapes, whole-object fallbacks, and PPTX editability.
- Adds deterministic module grouping metadata so captured card, section, table, and visual-module objects can be recognized together.
- Lets captured modules be selected as a group from the Inspector, then moved, nudged, aligned, snapped, duplicated, deleted, locked, or refined internally with same-width, same-height, and equal-spacing commands.
- Shows editability metadata for captured objects, including directly editable text, replaceable images, adjustable shapes, approximated pseudo-elements, and iframe/canvas whole-object fallbacks.
- Uses consistent page/slide boundary detection for editable capture and export.
- Detects runtime roots, scripts, embedded pages, canvas regions, shadow components, external runtime resources, and transparent selection blockers.
- Makes dynamically inserted titles, images, tables, and modules join the editing and delivery-check pipeline after import.
- Temporarily lets empty transparent hit layers pass through clicks inside the editor so the real visible object underneath can be selected.
- Adds dynamic-content risk rows, issue icons, export scoring penalties, and guidance for when `转为可编辑版` is the safer precision-editing path.
- Keeps exported HTML clean by stripping Chiselo editing markers before delivery.
- Updates packaging to `0.1.6`.

## Who This Preview Is For

- People who already have an HTML page, document, report, dashboard, poster, or presentation-like file.
- People who already have HTML files and need precise second-pass editing and delivery.
- People testing dynamic HTML that may rely on scripts, embedded content, canvas, or runtime resources.
- People who want delivery checks before exporting HTML, PDF, or PPTX.
- Personal, educational, research, evaluation, and non-commercial hobby users.

Commercial use is not allowed under the included license.

## Highlights

- Open HTML documents and Chiselo project files (`.html`, `.htm`, `.xhtml`, `.aislide`, `.json`).
- Select visible page objects directly on the canvas.
- Edit text in place.
- Move, resize, align, duplicate, delete, and adjust layer order.
- Select captured cards/modules as one group after `转为可编辑版` for safer second-pass layout changes and internal spacing cleanup.
- Replace images with embedded PNG/JPG/GIF/SVG/WebP data URLs.
- Edit tables, including safer handling for `rowspan` and `colspan`.
- Show page/canvas boundaries, center lines, ruler ticks, snapping guides, and distribution controls.
- Run delivery checks for broken resources, SVG usage, clean HTML export, text overflow, out-of-bounds elements, overlaps, and dynamic-content risks.
- Restore save snapshots from `.chiselo-history/`.
- Export clean standalone HTML.
- Export high-fidelity PDF.
- Export best-effort object-editable PPTX.

## Install

1. Download `Chiselo-0.1.6.dmg` after the GitHub Release asset is published.
2. Open the DMG.
3. Drag `Chiselo.app` to `Applications`.
4. Launch Chiselo.

This preview build is ad-hoc signed and not notarized. If macOS blocks the first launch, read the included `首次打开帮助.txt`.

For GitHub Releases, publish the final downloadable build as a normal release instead of a pre-release when the website button should always resolve to the newest asset through `/releases/latest`.

## Known Limitations

Chiselo is an early preview. The following areas are still active research:

- complex scripts;
- responsive layouts;
- pseudo-elements;
- animations;
- cross-origin resources;
- canvas pixels, closed components, and cross-origin embedded pages that cannot be decomposed into normal editable objects;
- perfect PPTX mapping for every CSS effect.

For important files, keep the `.chiselo-backup` and `.chiselo-history/` files until you have reviewed the final output.

## License

Chiselo is source-available for personal, educational, research, evaluation, and non-commercial hobby use only.

Commercial use is forbidden. This is not an OSI-approved open source license.
