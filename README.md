# Chiselo

[![CI](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml/badge.svg)](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/JunZhaoNathan/Chiselo?display_name=tag&label=latest)](https://github.com/JunZhaoNathan/Chiselo/releases/latest)
[![License: Non-Commercial](https://img.shields.io/badge/license-non--commercial-orange)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/JunZhaoNathan/Chiselo?style=social)](https://github.com/JunZhaoNathan/Chiselo/stargazers)

**Chisel your HTML.**

Chiselo is a native macOS app for high-fidelity refinement and delivery of existing HTML files.

中文定位：Chiselo 是一款 HTML 精修与交付工具。打开已有 HTML 页面/文档，像整理交付稿一样精修文字、图片、表格、模块和版式，然后导出干净 HTML、高保真 PDF 或尽量可编辑的 PPTX。

Chiselo starts from an existing HTML document. It is a finishing and delivery workflow, not a project authoring environment. The core promise is simple:

**Bring in your HTML, refine it visually, preflight delivery, then export.**

![Chiselo editor preview](assets/chiselo-editor-preview.png)

## Download

Current source and package version: `0.1.6`.

The latest published DMG is still `Chiselo-0.1.4.dmg` until the next GitHub Release asset is uploaded.

- [Latest Release](https://github.com/JunZhaoNathan/Chiselo/releases/latest)
- [0.1.6 Preview Notes](docs/releases/RELEASE_NOTES_0.1.6_PREVIEW.md)
- [Latest Published Release Notes](docs/releases/RELEASE_NOTES_0.1.4_PREVIEW.md)

The preview build is ad-hoc signed and not notarized. If macOS blocks the first launch, the DMG includes `首次打开帮助.txt` with step-by-step fixes for `Open Anyway`, Finder right-click `Open`, and quarantine removal.

## Why Chiselo

- HTML stays the editable source document.
- The browser-rendered page stays the source of truth.
- Chiselo adds object-level visual finishing controls on top of the rendered document.
- Delivery checks and exports focus on HTML/PDF/PPTX quality.
- Dynamic and script-rendered HTML is handled as a compatibility case, not the product identity.

## What You Can Do

- Open HTML documents and Chiselo project files (`.html`, `.htm`, `.xhtml`, `.aislide`, `.json`).
- Drag HTML files into the app window or onto `Chiselo.app`.
- Click directly on the rendered page to select visible objects.
- Double-click text in place to edit it.
- Drag, resize, align, nudge, duplicate, delete, and reorder elements.
- Multi-select page objects with Shift/Cmd-click.
- Replace images with embedded PNG/JPG/GIF/SVG/WebP data URLs.
- Edit tables, including safer handling for `rowspan` and `colspan`.
- Run a delivery check for broken resources, SVG usage, clean HTML export, text overflow, out-of-bounds elements, and overlaps.
- Identify script-rendered HTML, embedded pages, canvas regions, external runtime resources, and transparent selection blockers before export.
- Convert a live HTML rendering into a structured precision-editing tab.
- Export clean standalone HTML, high-fidelity PDF, and best-effort editable PPTX.

## Typical Workflow

1. Open Chiselo.
2. Drag in an existing HTML file.
3. Click a visible element on the page.
4. Edit text, move layout, adjust objects, replace images, and fix tables.
5. Run the delivery check.
6. Export HTML, PDF, or PPTX.

User docs:

- [Install](docs/user/INSTALL.md)
- [Usage Guide](docs/user/USAGE.md)

## Product Status

Chiselo is an early preview. It already edits rendered HTML objects and saves changes back to HTML, but complex scripts, responsive layouts, pseudo-elements, animations, cross-origin resources, and perfect multi-format output are still active research areas.

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
