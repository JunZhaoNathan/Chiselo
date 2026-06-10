# Chiselo

[![CI](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml/badge.svg)](https://github.com/JunZhaoNathan/Chiselo/actions/workflows/ci.yml)
[![Preview Release](https://img.shields.io/github/v/release/JunZhaoNathan/Chiselo?display_name=tag&include_prereleases&label=preview)](https://github.com/JunZhaoNathan/Chiselo/releases)
[![License: Non-Commercial](https://img.shields.io/badge/license-non--commercial-orange)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/JunZhaoNathan/Chiselo?style=social)](https://github.com/JunZhaoNathan/Chiselo/stargazers)

**Chisel your HTML.**

Chiselo is a native macOS app for polishing existing or AI-generated HTML with an Office-like visual editing layer and multi-format output.

中文定位：Chiselo 用来打磨你的 HTML。HTML 是主资产，Chiselo 在真实浏览器渲染之上提供 Office-like / PPT-like 的可视化编辑层，让你像修改 Office 或 PPT 一样，直接修改 AI 生成或现有的网页、文档、海报、仪表盘和 HTML 演示。

It is not a site builder, not a rich text editor, and not only an HTML-to-PPT tool. The core promise is simple:

**Bring in your HTML, fix text and layout visually, then export deliverables.**

![Chiselo editor preview](assets/chiselo-editor-preview.png)

## Download

The latest public preview is `Chiselo-0.1.3.dmg`.

- [Preview Release](https://github.com/JunZhaoNathan/Chiselo/releases/tag/v0.1.3-preview.1)
- [Release Notes](docs/releases/RELEASE_NOTES_0.1.3_PREVIEW.md)

The preview build is ad-hoc signed and not notarized. If macOS blocks the first launch, the DMG includes `首次打开帮助.txt` with step-by-step fixes for `Open Anyway`, Finder right-click `Open`, and quarantine removal.

## Why Chiselo

- HTML stays the primary asset.
- The browser-rendered page stays the source of truth.
- Chiselo adds direct visual editing on top of the real DOM.
- HTML, PDF, and PPTX are delivery formats, not the product identity.

## What You Can Do

- Open `.html`, `.htm`, `.xhtml`, `.aislide`, and `.json` files.
- Drag HTML files into the app window or onto `Chiselo.app`.
- Click directly on the rendered HTML body to select real DOM elements.
- Double-click text in place to edit it.
- Drag, resize, align, nudge, duplicate, delete, and reorder elements.
- Multi-select real DOM nodes with Shift/Cmd-click.
- Replace images with embedded PNG/JPG/GIF/SVG/WebP data URLs.
- Edit tables, including safer handling for `rowspan` and `colspan`.
- Run a delivery check for broken resources, SVG usage, clean HTML export, text overflow, out-of-bounds elements, and overlaps.
- Freeze a live HTML rendering into a structured precision-editing tab.
- Export clean standalone HTML, high-fidelity PDF, and best-effort editable PPTX.

## Typical Workflow

1. Open Chiselo.
2. Drag in an AI-generated HTML file.
3. Click a visible element on the page.
4. Edit text, move layout, adjust objects, replace images, and fix tables.
5. Run the delivery check.
6. Export HTML, PDF, or PPTX.

User docs:

- [Install](docs/user/INSTALL.md)
- [Usage Guide](docs/user/USAGE.md)

## Product Status

Chiselo is an early preview. It already edits real HTML DOM nodes, but complex scripts, responsive layouts, pseudo-elements, animations, cross-origin resources, and perfect multi-format output are still active research areas.

PDF remains the recommended final format when maximum fidelity matters.

## Creator Note

Chiselo is intentionally transparent about how it was made. The project was started by a humanities-background creator using vibe coding with AI assistance, especially Codex and GPT.

That history matters because the product is not trying to look like a generic internal tool. It is trying to make AI-generated HTML genuinely editable and usable for more people.

If Chiselo helps you or you are interested in AI-generated HTML, visual editing, or AI-native software creation, please star the repository so more people can find the project.

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
examples/                 sample .aislide and HTML fixtures
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
