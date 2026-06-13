# Chiselo 0.1.9 Preview

Chiselo is a native macOS app for high-fidelity refinement and delivery of existing HTML files.

中文：Chiselo 是一款 HTML 精修与交付工具。打开已有 HTML 页面/文档，精修文字、图片、表格、模块和版式，交付前预检问题，然后导出干净 HTML、高保真 PDF 或尽量可编辑的 PPTX。

## What Changed In 0.1.9

- Adds `建议操作` to PPTX preflight so detected risks have direct next-step buttons instead of only warnings.
- Lets users locate tables, SVG/vector objects, complex visual effects, and layered objects from the export panel.
- Adds a direct `转为可编辑版` action for dynamic or whole-object HTML that needs stable precision editing before export.
- Adds a direct PDF fallback action when visual fidelity is more important than editable PPTX output.
- Updates packaging to `0.1.9`.

## Why This Matters

Chiselo's delivery check is becoming a closed loop: detect the risky object, move through each object, then take the next delivery action from the same panel. This keeps the product focused on precise HTML finishing and high-fidelity delivery instead of drifting toward website building.

## Install

1. Download `Chiselo-0.1.9.dmg` after the GitHub Release asset is published.
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
