# Chiselo 0.1.4 Preview

Chiselo is a native macOS app for polishing existing or AI-generated HTML with an Office-like visual editing layer and multi-format output.

中文：Chiselo 用来打磨你的 HTML。HTML 是主资产，Chiselo 在真实浏览器渲染之上提供类似 Office / PPT 的可视化编辑层，让你快速修文字、修布局、调元素，然后导出可交付文件。

Creator note: Chiselo was built through vibe coding by a humanities-background creator who does not come from a programming background. Thanks to Codex and GPT for making this kind of software exploration possible.

## What Changed In 0.1.4

- Added safer real-file editing for local HTML and Chiselo deck files.
- Opening a real file now creates a one-time sibling `.chiselo-backup` copy and keeps any existing backup instead of replacing it.
- Saving over an existing HTML, `.aislide`, or `.json` deck now writes a timestamped snapshot into a sibling `.chiselo-history/` folder before overwriting.
- Added toolbar actions to reveal the current file's backup/history folder and restore the newest saved snapshot with confirmation.
- Added a safe-file-history regression test covering backup preservation and same-second snapshot ordering.
- Kept the generated fixture editing regression passing for 3 HTML pages and a 10-slide deck: text edits, image replacement, module movement, table edits, deck edits, duplicate/delete, and clean export.

## Who This Preview Is For

- People who already have an HTML page, document, poster, dashboard, or HTML slide-style presentation.
- People using AI to generate HTML and then needing a fast visual editing pass.
- People who want extra protection before editing real local files instead of only working on copies.
- Personal, educational, research, evaluation, and non-commercial hobby users.

Commercial use is not allowed under the included license.

## Highlights

- Open `.html`, `.htm`, `.xhtml`, `.aislide`, and `.json` files.
- Drag HTML files into the app.
- Select real rendered DOM elements directly on the canvas.
- Edit text in place.
- Move, resize, align, duplicate, delete, and adjust layer order.
- Multi-select real DOM nodes with Shift/Cmd-click.
- Replace images with embedded PNG/JPG/GIF/SVG/WebP data URLs.
- Edit tables, including safer handling for `rowspan` and `colspan`.
- Run delivery checks for broken resources, SVG usage, clean HTML export, text overflow, out-of-bounds elements, and overlaps.
- Restore recent save snapshots from `.chiselo-history/`.
- Export clean standalone HTML.
- Export high-fidelity PDF.
- Export best-effort object-editable PPTX.

## Install

1. Download `Chiselo-0.1.4.dmg`.
2. Open the DMG.
3. Drag `Chiselo.app` to `Applications`.
4. Launch Chiselo.

This preview build is ad-hoc signed and not notarized. If macOS blocks the first launch, read the included `首次打开帮助.txt`.

## Known Limitations

Chiselo is an early preview. The following areas are still active research:

- complex scripts;
- responsive layouts;
- pseudo-elements;
- animations;
- cross-origin resources;
- perfect PPTX mapping for every CSS effect.

For important files, keep the generated `.chiselo-backup` and `.chiselo-history/` files until you have reviewed the final output.

## License

Chiselo is source-available for personal, educational, research, evaluation, and non-commercial hobby use only.

Commercial use is forbidden. This is not an OSI-approved open source license.
