# Chiselo 0.1.2 Preview

Chiselo is a native macOS app for polishing existing or AI-generated HTML with an Office-like visual editing layer and multi-format output.

中文：Chiselo 用来打磨你的 HTML。HTML 是主资产，Chiselo 在真实浏览器渲染之上提供类似 Office / PPT 的可视化编辑层，让你快速修文字、修布局、调元素，然后导出可交付文件。

Creator note: Chiselo was built through vibe coding by a humanities-background creator who does not come from a programming background. Thanks to Codex and GPT for making this kind of software exploration possible.

## What Changed In 0.1.2

- Added clearer first-install guidance for new macOS users.
- Included `首次打开帮助.txt` inside the DMG package.
- Added specific solutions for `Open Anyway`, Finder right-click `Open`, and “move to trash / damaged” alerts.
- Documented the quarantine-removal command for trusted downloads.

## Who This Preview Is For

- People who already have an HTML page, document, poster, dashboard, or HTML slide-style presentation.
- People using AI to generate HTML and then needing a fast visual editing pass.
- Personal, educational, research, evaluation, and non-commercial hobby users.

Commercial use is not allowed under the included license.

## Highlights

- Open `.html`, `.htm`, `.xhtml`, `.aislide`, and `.json` files.
- Drag HTML files into the app.
- Select real rendered DOM elements directly on the canvas.
- Edit text in place.
- Move, resize, align, duplicate, delete, and adjust layer order.
- Use a DOM tree fallback for nested selections.
- Replace images with embedded data URLs.
- Edit table rows, columns, cells, and common table styles.
- Run delivery checks for broken resources, clean HTML export, SVG/table notices, overflow, out-of-bounds elements, and obvious overlaps.
- Export clean standalone HTML.
- Export high-fidelity PDF.
- Export best-effort object-editable PPTX.

## Install

1. Download `Chiselo-0.1.2.dmg`.
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

For important files, work on a copy and review exported output before delivery.

## License

Chiselo is source-available for personal, educational, research, evaluation, and non-commercial hobby use only.

Commercial use is forbidden. This is not an OSI-approved open source license.
