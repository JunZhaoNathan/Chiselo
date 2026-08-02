# Testing

## Fast Checks

```bash
swift build
swift test
node --check Chiselo/Resources/Editor/runtime-safety.js
node --check Chiselo/Resources/Editor/source-mapping.js
node --check Chiselo/Resources/Editor/visual-change.js
node --check Chiselo/Resources/Editor/editor-geometry.js
node --check Chiselo/Resources/Editor/editor.js
node scripts/editor-geometry-test.mjs
node --check scripts/generate-digital-transformation-slides.mjs
node scripts/validate-deck.mjs examples/sample.aislide
swiftc Chiselo/SafeFileHistory.swift scripts/safe-file-history-test.swift -o /tmp/chiselo-safe-file-history-test
/tmp/chiselo-safe-file-history-test
swiftc Chiselo/SafeFileHistory.swift Chiselo/HTMLSaveCoordinator.swift scripts/html-save-transaction-rollback-test.swift -o /tmp/chiselo-save-rollback-test
/tmp/chiselo-save-rollback-test
swift scripts/html-runtime-safety-test.swift
swift scripts/html-responsive-viewport-test.swift
swift scripts/direct-html-edit-isolation-test.swift
swift scripts/direct-html-edit-isolation-test.swift examples/test-html-pages/01-operations-dashboard.html
swift scripts/direct-html-canvas-interaction-test.swift examples/test-html-pages/01-operations-dashboard.html
```

## Release Preflight

```bash
scripts/release-preflight.sh
```

GitHub Actions runs this same complete preflight on every push and pull request, so CI and local release acceptance use one test entry point.

## Core Editor Checks

```bash
swift scripts/import-smoke-test.swift
swift scripts/html-delivery-diagnostics-test.swift
swift scripts/html-diagnostics-webpage-flow-test.swift
swift scripts/html-visual-snapshot-test.swift
swift scripts/direct-html-source-cleanliness-test.swift
swift scripts/direct-html-stylesheet-writeback-test.swift
swift scripts/direct-html-edit-isolation-test.swift
swift scripts/direct-html-canvas-interaction-test.swift
swift scripts/import-adapter-test.swift
swift scripts/generated-runtime-compatibility-test.swift
swift scripts/editable-layout-ir-test.swift
swift scripts/precision-adjustment-test.swift
swift scripts/five-slide-acceptance-test.swift
swift scripts/generated-fixtures-editing-test.swift
node scripts/validate-deck.mjs outputs/generated-fixture-edits/test-10-slide-deck-edited.aislide
```

These use the bundled sample HTML page unless you pass a custom HTML path.
Release preflight runs both edit-isolation and canvas-interaction coverage against the sample page, operations dashboard, editorial brief, and delivery form. Canvas interaction includes zoom in/out, cross-frame pointer release, high-zoom drag and resize accuracy, post-release stability, and non-target style, pseudo-element, geometry, and source preservation.
`generated-fixtures-editing-test.swift` is a legacy-named regression that edits bundled HTML and Chiselo project fixtures with the Chiselo editor runtime, exports the edited files to `outputs/generated-fixture-edits/`, and checks text editing, image replacement, module movement, table edits, project edits, and clean export.

## Demo Page Checks

```bash
node scripts/generate-digital-transformation-slides.mjs
swift scripts/digital-transformation-acceptance-test.swift
swift scripts/html-slide-visual-qa.swift
```

## Export Checks

```bash
swiftc Chiselo/HTMLRenderExporter.swift scripts/export-html-high-fidelity.swift -o /tmp/chiselo-export-test
/tmp/chiselo-export-test outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-10-slides.pdf pdf
/tmp/chiselo-export-test outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-10-slides-editable.pptx editable-pptx
/tmp/chiselo-export-test outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-10-slides-image.pptx image-pptx
scripts/editable-pptx-export-test.sh
scripts/pptx-design-absorption-test.sh
```

## Real-World Regression Files

Keep private or third-party HTML fixtures outside the repository unless they can be legally redistributed. Pass them explicitly:

```bash
swift scripts/import-smoke-test.swift /path/to/document.html
swift scripts/direct-html-canvas-interaction-test.swift /path/to/document.html
```
