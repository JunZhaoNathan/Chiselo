# Chiselo

[![CI](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml/badge.svg)](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml)
[![Preview Release](https://img.shields.io/github/v/release/JunZhaoNathan/Chiselo?display_name=tag&include_prereleases&label=preview)](https://github.com/JunZhaoNathan/Chiselo/releases)
[![License: Non-Commercial](https://img.shields.io/badge/license-non--commercial-orange)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/JunZhaoNathan/Chiselo?style=social)](https://github.com/JunZhaoNathan/Chiselo/stargazers)

**Chisel your HTML.**

中文定位：Chiselo 用来打磨你的 HTML。HTML 是主资产，Chiselo 在真实浏览器渲染之上提供 Office-like / PPT-like 的可视化编辑层，让你修改 AI 生成或现有的网页、文档、海报、仪表盘和 HTML 演示，再导出为干净 HTML、PDF 或 PPTX。

If you are interested in AI-generated HTML, visual editing, or software built through vibe coding, please star this repository so more people can find the project.

Chiselo is a native macOS editor built around **HTML as the primary asset + an Office-like visual editing layer + multi-format output**. It is for polishing AI-generated or existing HTML pages, A4 documents, posters, dashboards, and HTML slide-style presentations.

It is not a rich text editor and not a format converter. The goal is an **Office-like visual editing layer for HTML**: keep the browser-rendered HTML as the real document, then let people select visible objects, move them, resize them, edit text, repair tables/images, and deliver the result as clean HTML, high-fidelity PDF, or best-effort object-editable PPTX.

## Project Status

Chiselo is an early development preview. It already edits real HTML DOM nodes, but complex scripts, responsive layouts, pseudo-elements, animations, cross-origin resources, and perfect multi-format output are still active research areas.

This repository is intentionally transparent: Chiselo is a vibe-coded project started by a humanities-background creator who does not come from a programming background. The project was built with AI assistance, especially Codex and GPT. Code quality is being improved in public, step by step.

## Creator Note

我是一个文科生，不懂代码。Chiselo 是我用 vibe coding 一步步做出来的软件实验：把想法讲清楚，让 AI 帮我写、改、测试、重构，再反复打磨成一个真正能用的 macOS 应用。

感谢 Codex 和 GPT。没有这些工具，我很难把“像 Office 一样打磨 HTML”这个想法推进到可运行的软件。

如果你觉得这个方向有价值，欢迎 star。它会帮助更多人看到这个项目，也会给我继续打磨下去的动力。

## Preview Download

The latest public preview is prepared for GitHub Releases as `Chiselo-0.1.1.dmg`.

Release notes are in [docs/RELEASE_NOTES_0.1.1_PREVIEW.md](docs/RELEASE_NOTES_0.1.1_PREVIEW.md). Publishing steps are in [docs/GITHUB_PUBLISHING.md](docs/GITHUB_PUBLISHING.md).

![Chiselo editor preview](assets/chiselo-editor-preview.png)

## License

Chiselo is source-available for personal, educational, research, and evaluation use only.

Commercial use is not allowed. This includes selling Chiselo, using it in paid services, using it inside a commercial product, using it for paid client delivery, or using it internally for business operations.

See [LICENSE](LICENSE). This is a non-commercial license and is not an OSI-approved open source license.

## What It Can Do

- Open `.html`, `.htm`, `.xhtml`, `.aislide`, and `.json` files.
- Drag external HTML files into the app window or onto `Chiselo.app`.
- Use browser-style tabs for multiple HTML/deck documents.
- Click directly on the rendered HTML body to select DOM elements.
- Double-click headings, paragraphs, spans, list items, and table cells to edit text in place.
- Zoom the canvas with Command + mouse wheel.
- Drag, resize, align, nudge, duplicate, delete, and change layer order.
- Multi-select real DOM nodes with Shift/Cmd-click.
- Use a DOM tree as a fallback for nested element selection.
- Replace selected images with embedded PNG/JPG/GIF/SVG/WebP data URLs.
- Detect broken images and media resources while keeping exports clean.
- Show a delivery check for broken resources, complex tables, SVG usage, clean HTML export, text overflow, out-of-bounds elements, and obvious overlaps.
- Add/delete table rows and columns, including safer handling for `rowspan` and `colspan`.
- Adjust text, fill, border, radius, alignment, and cell styles.
- Freeze an HTML rendering into a structured editable layout tab for more Office-like precise adjustments.
- Export clean standalone HTML.
- Export high-fidelity PDF by rendering each detected page/slide.
- Export best-effort object-level PPTX with editable text boxes, shapes, tables, and image objects where possible.

## Search Keywords

AI-generated HTML editor, AI HTML editor, visual HTML editor, editable HTML editor, WYSIWYG HTML layout editor, HTML layout editor, Office-like HTML editor, PPT-like HTML editor, HTML presentation editor, macOS HTML editor, WKWebView editor, HTML to PDF, HTML to PPTX, html-to-pptx, html2pptx, html2ppt, source-available non-commercial software, vibe coding app.

## Install

Download the latest DMG from GitHub Releases once releases are published.

For the preview release, download `Chiselo-0.1.1.dmg`, open it, and drag `Chiselo.app` to `Applications`.

For local development builds:

```bash
scripts/package-dmg.sh
```

The package script writes:

```text
outputs/Chiselo.app
outputs/Chiselo-0.1.1.dmg
```

To write package artifacts somewhere else:

```bash
OUTPUT_DIR=/path/to/output scripts/package-dmg.sh
```

The DMG is currently ad-hoc signed and not notarized. On first launch, macOS may require Finder right-click -> Open.

## Run From Source

Requirements:

- macOS 13 or newer
- Xcode command line tools
- Swift 5.9 or newer
- Node.js for helper scripts

```bash
swift run Chiselo
```

## Design Tokens

Chiselo uses `design-tokens.json` as the single source for shared SwiftUI and Web editor theme values.

After changing tokens, regenerate the derived files:

```bash
node scripts/generate-design-tokens.mjs
```

This updates `Chiselo/MaterialTheme.swift` and `Chiselo/Resources/Editor/design-tokens.css`. The release/package scripts run this step automatically.

## Basic Workflow

1. Open Chiselo.
2. Drag an AI-generated HTML file into the window.
3. Click an element on the rendered page.
4. Drag or resize it on the canvas, or use the inspector for exact geometry.
5. Double-click text to edit it in place.
6. Use image/table controls when the selected object supports them.
7. Export to the delivery format you need: clean HTML, PDF, or PPTX.

More detail: [Usage Guide](docs/USAGE.md).

## Build And Test

```bash
swift build
node --check Chiselo/Resources/Editor/editor.js
swift scripts/import-smoke-test.swift
swift scripts/bridge-message-efficiency-test.swift
swift scripts/html-delivery-diagnostics-test.swift
swift scripts/html-diagnostics-webpage-flow-test.swift
swift scripts/deck-gesture-smoothness-test.swift
swift scripts/direct-html-canvas-interaction-test.swift
swift scripts/import-adapter-test.swift
swift scripts/precision-adjustment-test.swift
swift scripts/five-slide-acceptance-test.swift
swift scripts/html-tree-mutation-throttle-test.swift
```

Before a release, run the combined preflight:

```bash
scripts/release-preflight.sh
```

Generate and test the 10-page digital transformation demo:

```bash
node scripts/generate-digital-transformation-slides.mjs
swift scripts/digital-transformation-acceptance-test.swift
swift scripts/html-slide-visual-qa.swift
```

More detail: [Testing Guide](docs/TESTING.md).

## Export Validation

```bash
swiftc Chiselo/HTMLRenderExporter.swift scripts/export-html-high-fidelity.swift -o /tmp/chiselo-export-test
/tmp/chiselo-export-test outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-10-slides.pdf pdf
/tmp/chiselo-export-test outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-10-slides-editable.pptx editable-pptx
/tmp/chiselo-export-test outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-10-slides-image.pptx image-pptx
scripts/editable-pptx-export-test.sh
scripts/pptx-design-absorption-test.sh
```

PPTX is one delivery target for users who need object-level editability outside Chiselo. If a CSS effect cannot be mapped faithfully, PDF remains the preferred high-fidelity final format.

## Repository Map

```text
Chiselo/                  macOS SwiftUI app and exporter
Chiselo/Resources/Editor/ WKWebView HTML editor
assets/                           public screenshots and repository media
scripts/                          QA, export, icon, demo, and packaging scripts
examples/                         sample .aislide and HTML fixtures
docs/                             architecture, usage, testing, release notes
```

## Roadmap

See [Roadmap](docs/ROADMAP.md).

Near-term priorities:

- More precise hover actions and selection affordances.
- Stronger grouping, guides, rulers, and distribution controls.
- Better responsive layout freezing.
- Visual diff and save preview before overwriting HTML.
- Deeper PPTX object mapping for tables, SVG, and CSS effects.

## Contributing

Personal-use contributions are welcome under the same non-commercial license. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

For bugs and feature requests, use the GitHub issue templates. For private security concerns, see [SECURITY.md](SECURITY.md).
