#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_with_retry() {
  local attempts="$1"
  shift
  local attempt=1

  until "$@"; do
    if (( attempt >= attempts )); then
      return 1
    fi
    attempt=$((attempt + 1))
    echo "Retrying command after transient failure: $*"
    sleep 2
  done
}

echo "==> Checking for local-only paths and old project names"
LOCAL_PATH_OR_OLD_NAME_PATTERN="/Users/[^[:space:]'\"]+|/var/folders/|TemporaryItems|Documents/Codex|Htmlhunter|htmlhunter|HTMLHUNTER"
if command -v rg >/dev/null 2>&1; then
  LOCAL_PATH_MATCHES="$(rg -n "$LOCAL_PATH_OR_OLD_NAME_PATTERN" \
    -g '!.git/**' \
    -g '!.build/**' \
    -g '!outputs/**' \
    -g '!scripts/release-preflight.sh' \
    . || true)"
else
  LOCAL_PATH_MATCHES="$(grep -RInE \
    --exclude-dir=.git \
    --exclude-dir=.build \
    --exclude-dir=outputs \
    --exclude=release-preflight.sh \
    "$LOCAL_PATH_OR_OLD_NAME_PATTERN" . || true)"
fi
if [[ -n "$LOCAL_PATH_MATCHES" ]]; then
  printf '%s\n' "$LOCAL_PATH_MATCHES"
  echo "Found local-only paths or old project names." >&2
  exit 1
fi

echo "==> Release metadata"
node -e '
const release = require("./config/release.json");
if (!/^\d+\.\d+\.\d+$/.test(release.version)) throw new Error("release.version must use semantic version form");
if (!/^\d+$/.test(release.buildNumber) || Number(release.buildNumber) < 1) throw new Error("release.buildNumber must be a positive integer string");
'
RELEASE_VERSION="$(node -p "require('./config/release.json').version")"
test -f "docs/releases/RELEASE_NOTES_${RELEASE_VERSION}_PREVIEW.md"
bash -n scripts/package-dmg.sh scripts/publish-public-release.sh scripts/publish-r2-release.sh scripts/verify-online-update.sh
swift scripts/chiselo-sparkle-tool.swift help >/dev/null

echo "==> Swift build"
node scripts/generate-design-tokens.mjs
swift build
swift test

echo "==> JavaScript syntax"
node --check scripts/generate-design-tokens.mjs
node --check Chiselo/Resources/Editor/runtime-safety.js
node --check Chiselo/Resources/Editor/source-mapping.js
node --check Chiselo/Resources/Editor/visual-change.js
node --check Chiselo/Resources/Editor/editor-geometry.js
node --check Chiselo/Resources/Editor/editor.js
node --check scripts/generate-digital-transformation-slides.mjs

echo "==> Sample deck schema"
node scripts/validate-deck.mjs examples/sample.aislide

echo "==> Safe file history"
SAFE_HISTORY_TEST_BIN="/tmp/chiselo-safe-file-history-test"
swiftc Chiselo/SafeFileHistory.swift scripts/safe-file-history-test.swift -o "$SAFE_HISTORY_TEST_BIN"
"$SAFE_HISTORY_TEST_BIN"
VISUAL_FILTER_TEST_BIN="/tmp/chiselo-visual-change-filter-test"
swiftc Chiselo/DeckModel.swift scripts/visual-change-filter-test.swift -o "$VISUAL_FILTER_TEST_BIN"
"$VISUAL_FILTER_TEST_BIN"
node scripts/editor-geometry-test.mjs

echo "==> Core editor smoke tests"
swift scripts/import-smoke-test.swift
swift scripts/bridge-message-efficiency-test.swift
swift scripts/html-delivery-diagnostics-test.swift
swift scripts/html-diagnostics-webpage-flow-test.swift
swift scripts/html-precision-editing-diagnostics-test.swift
swift scripts/html-visual-snapshot-test.swift
swift scripts/visual-change-revert-test.swift
swift scripts/visual-change-added-revert-test.swift
swift scripts/deck-gesture-smoothness-test.swift
swift scripts/direct-html-source-cleanliness-test.swift
swift scripts/direct-html-source-sync-test.swift
swift scripts/direct-html-attributes-insert-test.swift
swift scripts/direct-html-stylesheet-writeback-test.swift
swift scripts/direct-html-rule-editor-test.swift
LOCAL_STYLESHEET_SAVE_TEST_BIN="/tmp/chiselo-local-stylesheet-save-test"
swiftc Chiselo/SafeFileHistory.swift Chiselo/HTMLSaveCoordinator.swift scripts/direct-html-local-stylesheet-save-test.swift -o "$LOCAL_STYLESHEET_SAVE_TEST_BIN"
"$LOCAL_STYLESHEET_SAVE_TEST_BIN"
SAVE_ROLLBACK_TEST_BIN="/tmp/chiselo-save-transaction-rollback-test"
swiftc Chiselo/SafeFileHistory.swift Chiselo/HTMLSaveCoordinator.swift scripts/html-save-transaction-rollback-test.swift -o "$SAVE_ROLLBACK_TEST_BIN"
"$SAVE_ROLLBACK_TEST_BIN"
swift scripts/html-runtime-safety-test.swift
EXPORT_RUNTIME_SAFETY_TEST_BIN="/tmp/chiselo-export-runtime-safety-test"
swiftc Chiselo/HTMLRenderExporter.swift scripts/export-runtime-safety-test.swift -o "$EXPORT_RUNTIME_SAFETY_TEST_BIN"
"$EXPORT_RUNTIME_SAFETY_TEST_BIN"
swift scripts/html-responsive-viewport-test.swift
swift scripts/direct-html-pseudo-preview-test.swift
swift scripts/direct-html-editor-shell-stability-test.swift
swift scripts/direct-html-responsive-change-review-test.swift
swift scripts/direct-quick-actions-compact-test.swift
swift scripts/direct-html-table-cell-geometry-lock-test.swift
swift scripts/direct-html-edit-isolation-test.swift
for real_case in \
  examples/sample-html-page.html \
  examples/test-html-pages/01-operations-dashboard.html \
  examples/test-html-pages/02-editorial-brief.html \
  examples/test-html-pages/03-delivery-form.html; do
  swift scripts/direct-html-edit-isolation-test.swift "$real_case"
  run_with_retry 2 swift scripts/direct-html-canvas-interaction-test.swift "$real_case"
done
swift scripts/import-adapter-test.swift
swift scripts/precision-adjustment-test.swift
swift scripts/five-slide-acceptance-test.swift
swift scripts/generated-fixtures-editing-test.swift
node scripts/validate-deck.mjs outputs/generated-fixture-edits/test-10-slide-deck-edited.aislide

echo "==> Demo acceptance"
node scripts/generate-digital-transformation-slides.mjs
swift scripts/digital-transformation-acceptance-test.swift

echo "==> Visual QA"
swift scripts/html-slide-visual-qa.swift outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-visual-qa
swift scripts/html-slide-visual-qa.swift outputs/chiselo-five-slide-demo-edited.html outputs/chiselo-five-slide-visual-qa

echo "==> Export validation"
EXPORT_TEST_BIN="/tmp/chiselo-export-preflight"
swiftc Chiselo/HTMLRenderExporter.swift scripts/export-html-high-fidelity.swift -o "$EXPORT_TEST_BIN"
"$EXPORT_TEST_BIN" outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-10-slides.pdf pdf
"$EXPORT_TEST_BIN" outputs/digital-transformation-10-slides-edited.html outputs/digital-transformation-10-slides-editable.pptx editable-pptx
if "$EXPORT_TEST_BIN" outputs/digital-transformation-10-slides-edited.html outputs/should-not-exist.pptx typo-pptx 2>/dev/null; then
  echo "Export CLI accepted an invalid format." >&2
  exit 1
fi
ORIENTATION_TEST_BIN="/tmp/chiselo-export-orientation-test"
swiftc Chiselo/HTMLRenderExporter.swift scripts/export-orientation-test.swift -o "$ORIENTATION_TEST_BIN"
"$ORIENTATION_TEST_BIN"
scripts/pptx-design-absorption-test.sh
scripts/editable-pptx-export-test.sh

echo "Preflight OK"
