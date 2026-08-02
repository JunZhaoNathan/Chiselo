# Chiselo

[![CI](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml/badge.svg)](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/JunZhaoNathan/Chiselo?display_name=tag&label=latest)](https://github.com/JunZhaoNathan/Chiselo/releases/latest)
[![License: Non-Commercial](https://img.shields.io/badge/license-non--commercial-orange)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/JunZhaoNathan/Chiselo?style=social)](https://github.com/JunZhaoNathan/Chiselo/stargazers)
[![Website](https://img.shields.io/badge/website-chiselo.vellumloop.com-216b62)](https://chiselo.vellumloop.com/)

**Chisel your HTML.**

Chiselo is a native macOS visual HTML editor for refining existing or AI-generated HTML files without turning them into a new website project.

中文定位：Chiselo 要取代 Dreamweaver 的“现有 HTML 可视化修改”工作流，而不是复制 Dreamweaver 的建站、FTP 和传统 IDE 功能。它直接打开已有或 AI 生成的成熟 HTML，让不懂复杂前端工具的用户精修文字、图片、表格、模块和版式，再安全保存或导出。

Chiselo starts from an existing HTML document. It is a finishing and delivery workflow, not a project authoring environment. The core promise is simple:

**Bring in your HTML, refine it visually, preflight delivery, then export.**

The product promise is deliberately focused: simpler visual editing for static and conventional AI-generated HTML; more reliable source preservation, saving, and change review; and an explicit trusted compatibility mode when a document depends on a complex dynamic runtime.

![Chiselo editor preview](assets/chiselo-editor-preview.png)

Website: [chiselo.vellumloop.com](https://chiselo.vellumloop.com/)

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

- HTML stays the editable source document.
- The browser-rendered page stays the source of truth.
- Chiselo adds object-level visual finishing controls on top of the rendered document.
- Delivery checks and exports focus on HTML/PDF/PPTX quality.
- Dynamic and script-rendered HTML is handled as a compatibility case, not the product identity.
- Ordinary mode keeps DOM, source, runtime, and PPTX complexity out of the default workflow; Advanced mode preserves those tools when needed.

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

For static pages and conventional AI-generated HTML, Chiselo covers the core workflow of a light Dreamweaver: rendered-object selection, visual editing, exact no-op round-trip, responsive preview, protected save, local CSS writeback, undo/redo, diagnostics, and high-fidelity PDF output. Its goal is to replace Dreamweaver's existing-HTML visual editing workflow, not its site management, FTP, or traditional IDE features. Complex scripts, pseudo-elements, animations, and cross-origin resources require trusted compatibility mode and continued review; perfectly editable PPTX output is also not guaranteed.

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
