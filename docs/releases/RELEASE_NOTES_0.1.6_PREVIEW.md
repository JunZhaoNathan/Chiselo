# Chiselo 0.1.6 Preview

Chiselo is a native macOS app for refining and delivering HTML pages and visual documents.

中文：Chiselo 是一款 HTML 精修与交付工具。打开现有或生成的 HTML 页面/文档，调整文字、图片、表格、模块和版式，交付前预检问题，然后导出干净 HTML、高保真 PDF 或尽量可编辑的 PPTX。

Creator note: Chiselo was built through vibe coding by a humanities-background creator who does not come from a programming background. Thanks to Codex and GPT for making this kind of software exploration possible.

## What Changed In 0.1.6

- Added generator compatibility diagnostics for Dify-like and script-rendered HTML.
- Detects runtime roots, scripts, embedded pages, canvas regions, shadow components, external runtime resources, and transparent selection blockers.
- Makes dynamically inserted titles, images, tables, and modules join the editing and delivery-check pipeline after import.
- Temporarily lets empty transparent hit layers pass through clicks inside the editor so the real visible object underneath can be selected.
- Adds generator compatibility rows, issue icons, export scoring penalties, and guidance for when Freeze Layout is the safer precision-editing path.
- Keeps exported HTML clean by stripping Chiselo editing markers before delivery.
- Updates packaging to `0.1.6`.

## Who This Preview Is For

- People who already have an HTML page, document, report, dashboard, poster, or presentation-like file.
- People who receive generated HTML and need a precise second-pass editing and delivery tool.
- People testing Dify-like generated HTML that may rely on scripts, embedded content, canvas, or runtime resources.
- People who want delivery checks before exporting HTML, PDF, or PPTX.
- Personal, educational, research, evaluation, and non-commercial hobby users.

Commercial use is not allowed under the included license.

## Highlights

- Open HTML documents and Chiselo project files (`.html`, `.htm`, `.xhtml`, `.aislide`, `.json`).
- Select visible page objects directly on the canvas.
- Edit text in place.
- Move, resize, align, duplicate, delete, and adjust layer order.
- Replace images with embedded PNG/JPG/GIF/SVG/WebP data URLs.
- Edit tables, including safer handling for `rowspan` and `colspan`.
- Show page/canvas boundaries, center lines, ruler ticks, snapping guides, and distribution controls.
- Run delivery checks for broken resources, SVG usage, clean HTML export, text overflow, out-of-bounds elements, overlaps, and generator compatibility risks.
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

For important files, keep the generated `.chiselo-backup` and `.chiselo-history/` files until you have reviewed the final output.

## License

Chiselo is source-available for personal, educational, research, evaluation, and non-commercial hobby use only.

Commercial use is forbidden. This is not an OSI-approved open source license.
