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
if rg -n "$LOCAL_PATH_OR_OLD_NAME_PATTERN" \
  -g '!.git/**' \
  -g '!.build/**' \
  -g '!outputs/**' \
  -g '!scripts/release-preflight.sh' \
  .; then
  echo "Found local-only paths or old project names." >&2
  exit 1
fi

echo "==> Swift build"
node scripts/generate-design-tokens.mjs
swift build

echo "==> JavaScript syntax"
node --check scripts/generate-design-tokens.mjs
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

echo "==> Core editor smoke tests"
swift scripts/import-smoke-test.swift
swift scripts/bridge-message-efficiency-test.swift
swift scripts/html-delivery-diagnostics-test.swift
swift scripts/html-diagnostics-webpage-flow-test.swift
swift scripts/html-visual-snapshot-test.swift
swift scripts/visual-change-revert-test.swift
swift scripts/deck-gesture-smoothness-test.swift
swift scripts/direct-html-source-cleanliness-test.swift
swift scripts/direct-html-stylesheet-writeback-test.swift
swift scripts/direct-html-responsive-change-review-test.swift
swift scripts/direct-quick-actions-compact-test.swift
run_with_retry 2 swift scripts/direct-html-canvas-interaction-test.swift
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
