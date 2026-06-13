# Chiselo 0.1.8 Preview

Chiselo is a native macOS app for high-fidelity refinement and delivery of existing HTML files.

中文：Chiselo 是一款 HTML 精修与交付工具。打开已有 HTML 页面/文档，精修文字、图片、表格、模块和版式，交付前预检问题，然后导出干净 HTML、高保真 PDF 或尽量可编辑的 PPTX。

## What Changed In 0.1.8

- Adds `逐项定位` to the `PPTX 可编辑对象` report so users can move through matching objects with previous/next controls before export.
- Tracks target lists for editable text, images, shapes, review objects, and whole-object fallbacks instead of only storing the first matching object.
- Lets export-risk groups such as tables, SVG/vector content, complex effects, layered objects, embedded pages, canvas regions, and script-rendered runtime roots be reviewed one by one.
- Adds regression coverage for multi-target PPTX review lists and dynamic HTML whole-object fallback navigation.
- Updates packaging to `0.1.8`.

## Why This Matters

High-quality delivery depends on finishing every risky object, not just finding the first one. This preview turns the PPTX preflight report into a review workflow: locate, check, move to the next object, and keep going until the export risks are understood.

## Install

1. Download `Chiselo-0.1.8.dmg` after the GitHub Release asset is published.
2. Open the DMG.
3. Drag `Chiselo.app` to `Applications`.
4. Launch Chiselo.

This preview build is ad-hoc signed and not notarized. If macOS blocks the first launch, read the included `首次打开帮助.txt`.

For GitHub Releases, publish the final downloadable build as a normal release instead of a pre-release when the website button should always resolve to the newest asset through `/releases/latest`.

## Known Limitations

Chiselo is an early preview. Complex scripts, responsive layouts, animations, pseudo-elements, canvas pixels, closed components, cross-origin embedded pages, and perfect editable PPTX mapping for every CSS effect still need ongoing work.

For important files, keep the `.chiselo-backup` and `.chiselo-history/` files until you have reviewed the final output.

## License

Chiselo is source-available for personal, educational, research, evaluation, and non-commercial hobby use only.

Commercial use is forbidden. This is not an OSI-approved open source license.
