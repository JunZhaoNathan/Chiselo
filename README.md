# Chiselo

[![CI](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml/badge.svg)](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/JunZhaoNathan/Chiselo?display_name=tag&label=latest)](https://github.com/JunZhaoNathan/Chiselo/releases/latest)
[![License: Non-Commercial](https://img.shields.io/badge/license-non--commercial-orange)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/JunZhaoNathan/Chiselo?style=social)](https://github.com/JunZhaoNathan/Chiselo/stargazers)
[![Website](https://img.shields.io/badge/website-chiselo.vellumloop.com-216b62)](https://chiselo.vellumloop.com/)

**Chisel your HTML.**

Chiselo is a native macOS visual HTML editor for existing web pages and visual documents. Open a finished `.html`, `.htm`, or `.xhtml` file, select what you see in the browser rendering, and edit text, images, tables, color, spacing, position, size, and layout directly.

中文定位：Chiselo 服务于“打开已有 HTML，再直接改页面”的工作流。它覆盖 Dreamweaver 用户最常见的页面修改场景：已有官网、落地页、报告、仪表盘、演示页面和 AI 生成的成熟 HTML，都可以在原文件基础上继续调整、复核、保存和交付。

HTML remains the working document throughout the session. Chiselo keeps source preservation, local editing, change review, protected saving, responsive preview, and delivery checks in one focused macOS app.

**Open existing HTML. Edit the rendered page. Save with confidence.**

![Chiselo editor preview](assets/chiselo-editor-preview.png)

Official website: [chiselo.vellumloop.com](https://chiselo.vellumloop.com/)

## Visual HTML Editing for Existing Pages

Chiselo is built for the moment after a page already exists and needs a precise human pass. It works well with hand-built HTML, exported web documents, static product pages, HTML reports, presentation pages, dashboards, and conventional AI-generated HTML.

People looking for a Dreamweaver alternative often need a quick, visual way to revise an existing file. Chiselo concentrates on that editing session: open the page, click the visible object, make the local change, inspect the result, and save the original document format.

### Edit rendered HTML directly

- Select the visible DOM element on the canvas instead of searching source code for its location.
- Double-click text to edit in place.
- Adjust typography, colors, borders, radius, shadows, spacing, geometry, alignment, layers, and image display from the visual Inspector.
- Move, resize, nudge, duplicate, delete, and reorder page objects with object-level controls.
- Edit tables with `rowspan` and `colspan` protection, replace images, and add common HTML elements when needed.

### Keep the source and the page stable

- Untouched HTML returns byte-for-byte unchanged.
- A selected local edit is isolated from unselected objects; zoom, drag, resize, text, and style regressions are checked against real HTML fixtures.
- Linked local CSS and HTML save as one rollback-capable transaction.
- Every opened document receives a backup and save history before a write reaches the original file.
- Visual change review shows changed text, images, geometry, and key styles before handoff.

### Review at the right width and deliver the right file

- Preview exact desktop (`1440px`), tablet (`768px`), and phone (`390px`) CSS widths without writing responsive preview state into the document.
- Check broken resources, text overflow, clipping, bounds, overlap, runtime risks, and source cleanliness.
- Save standalone HTML, export high-fidelity PDF, or export best-effort editable PPTX.
- Packaged macOS releases include Sparkle update checking, Developer ID signing, and notarized release artifacts.

### Work safely with complex pages

Chiselo opens HTML in static safety mode. Scripts, forms, and remote runtime privileges require an explicit trusted-document choice. Complex applications, cross-origin resources, animations, canvas regions, and pseudo-elements remain visible in diagnostics so the user can decide whether the page is suitable for a visual edit or needs a compatibility review.

## Chiselo and Vellumloop

Chiselo is made by [Vellumloop](https://vellumloop.com/), AI-era local-first software for serious work. Vellumloop keeps writing, planning, and creation where users remain in control. Its products give people a clear place to work with files, ideas, and AI assistance while preserving ownership and review.

- [Vellumloop](https://vellumloop.com/) — the parent studio and product directory
- [Chiselo website](https://chiselo.vellumloop.com/) — product information, installation guidance, and current release access
- [Chiselo Releases](https://github.com/JunZhaoNathan/Chiselo/releases/latest) — signed macOS DMG downloads and release notes

## Download

Current public version: `0.1.22`.

Download the latest packaged DMG from GitHub Releases after each published build.

- [Latest Release](https://github.com/JunZhaoNathan/Chiselo/releases/latest)
- [Chiselo Website](https://chiselo.vellumloop.com/)
- [0.1.22 Release Notes](docs/releases/RELEASE_NOTES_0.1.22_PREVIEW.md)
- [0.1.20 Preview Notes](docs/releases/RELEASE_NOTES_0.1.20_PREVIEW.md)
- [0.1.19 Preview Notes](docs/releases/RELEASE_NOTES_0.1.19_PREVIEW.md)
- [0.1.18 Preview Notes](docs/releases/RELEASE_NOTES_0.1.18_PREVIEW.md)
- [0.1.16 Preview Notes](docs/releases/RELEASE_NOTES_0.1.16_PREVIEW.md)
- [0.1.15 Preview Notes](docs/releases/RELEASE_NOTES_0.1.15_PREVIEW.md)
- [0.1.14 Preview Notes](docs/releases/RELEASE_NOTES_0.1.14_PREVIEW.md)
- [0.1.13 Preview Notes](docs/releases/RELEASE_NOTES_0.1.13_PREVIEW.md)
- [0.1.12 Preview Notes](docs/releases/RELEASE_NOTES_0.1.12_PREVIEW.md)
- [Release Guide](docs/dev/RELEASE.md)

The local preview package is Developer ID signed when the signing identity is available. Release packaging can be notarized and stapled with `CHISELO_NOTARIZE=1 scripts/package-dmg.sh`. The DMG includes `README.txt` and `更新说明.txt`; Sparkle update checking is enabled for packaged builds through the published appcast feed.

## Why Chiselo

- Existing HTML stays editable and portable.
- Browser rendering gives users a direct visual target for every change.
- Object-level controls keep page refinement approachable for people who do not work in code editors every day.
- Source preservation, protected saving, and change review make small visual corrections easier to verify.
- HTML, PDF, and PPTX outputs support distinct delivery needs.
- Static safety mode and trusted compatibility mode give dynamic pages a clear operational boundary.

## What You Can Do

- Open HTML documents and Chiselo project files (`.html`, `.htm`, `.xhtml`, `.aislide`, `.json`).
- Drag HTML files into the app window or onto `Chiselo.app`.
- Click directly on the rendered page to select visible objects.
- Double-click text in place to edit it.
- Drag, resize, align, nudge, duplicate, delete, and reorder elements.
- Refine typography, colors, borders, radius, shadows, and image display modes from the visual Inspector.
- Keep direct canvas editing single-selection first so one local edit does not move unrelated objects.
- Replace images with embedded PNG/JPG/GIF/SVG/WebP data URLs.
- Edit tables, including safer handling for `rowspan` and `colspan`.
- Run a delivery check for broken resources, SVG usage, clean HTML export, text overflow, out-of-bounds elements, and overlaps.
- Review object-level visual changes against the originally opened HTML before delivery.
- Identify script-rendered HTML, embedded pages, canvas regions, external runtime resources, and transparent selection blockers before export.
- Convert a live HTML rendering into a structured precision-editing tab.
- Export clean standalone HTML, high-fidelity PDF, and best-effort editable PPTX.
- Check for Sparkle updates from the packaged macOS app.
- Preview responsive CSS at exact `1440px`, `768px`, and `390px` viewports without modifying the document.
- Keep scripts and forms disabled by default, with an explicit trusted-document switch for dynamic compatibility.
- Preserve untouched HTML byte for byte, including formatting, until a real edit occurs.
- Protect unsaved tabs on close and quit, and save linked local CSS together with HTML as one rollback-capable transaction.
- Keep unselected modules geometrically stable when local text or visual styles change; overflow is reviewed instead of pushing unrelated content.
- Keep zoom level, document-space coordinates, and unrelated layout stable while dragging or resizing a selected HTML object at high magnification.

## Typical Workflow

1. Open Chiselo.
2. Drag in an existing HTML file.
3. Click a visible element on the page.
4. Edit text, move layout, adjust objects, replace images, and fix tables.
5. Check desktop, tablet, and phone widths when the page is responsive.
6. Save the HTML or run the delivery check and export.

User docs:

- [Install](docs/user/INSTALL.md)
- [Usage Guide](docs/user/USAGE.md)

## Product Status

For static pages and conventional AI-generated HTML, Chiselo covers the core light-Dreamweaver workflow: rendered-object selection, visual editing, exact no-op round-trip, responsive preview, protected save, local CSS writeback, undo/redo, diagnostics, and high-fidelity PDF output. The product scope centers on existing-HTML visual editing. Site management, FTP, backend development, framework tooling, databases, and general-purpose code authoring sit outside this focused workflow. Complex scripts, pseudo-elements, animations, and cross-origin resources require trusted compatibility mode and continued review; PPTX remains a best-effort editable export.

PDF remains the recommended final format when maximum fidelity matters.

## Creator Note

Chiselo's product scope is deliberately clear: make existing HTML pages and visual documents easier to refine, inspect, export, and hand off.

If Chiselo helps you or you are interested in precise HTML editing and visual delivery workflows, please star the repository so more people can find the project.

## Docs

- [Documentation Index](docs/README.md)
- [Developer Docs](docs/dev/architecture.md)
- [Testing](docs/dev/TESTING.md)
- [Roadmap](docs/dev/ROADMAP.md)
- [Changelog](docs/dev/CHANGELOG.md)

## Build From Source

Requirements:

- macOS 13 or newer
- Xcode command line tools
- Swift 5.9 or newer
- Node.js for helper scripts

```bash
swift run Chiselo
```

`Package.swift` is the Swift Package manifest. It tells `swift build` what the app target is, where the source lives, and which resources should be bundled, so it needs to stay at the repository root.

## Repository Layout

```text
Chiselo/                  macOS SwiftUI app and exporter
assets/                   screenshots and repository media
config/                   design and packaging configuration
docs/                     user docs, developer docs, and release notes
examples/                 sample Chiselo project and HTML fixtures
scripts/                  QA, export, icon, demo, and packaging scripts
```

## License

Chiselo is source-available for personal, educational, research, evaluation, and non-commercial use only.

Commercial use is not allowed. See [LICENSE](LICENSE).

## Contributing

Personal-use contributions are welcome under the same non-commercial license.

- [Contributing Guide](.github/CONTRIBUTING.md)
- [Security Policy](.github/SECURITY.md)
- [Code of Conduct](.github/CODE_OF_CONDUCT.md)
