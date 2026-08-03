#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/outputs}"
INPUT="${1:-$OUTPUT_DIR/digital-transformation-10-slides-edited.html}"
OUTPUT="${2:-$OUTPUT_DIR/digital-transformation-10-slides-editable.pptx}"
EXPORT_BIN="/tmp/chiselo-export-test"
WORK_DIR="$(mktemp -d /tmp/chiselo-editable-pptx-test.XXXXXX)"
QL_DIR="$(mktemp -d /tmp/chiselo-editable-pptx-ql.XXXXXX)"

cleanup() {
  rm -rf "$WORK_DIR" "$QL_DIR"
}
trap cleanup EXIT

swiftc "$ROOT_DIR/Chiselo/HTMLRenderExporter.swift" "$ROOT_DIR/scripts/export-html-high-fidelity.swift" -o "$EXPORT_BIN"
"$EXPORT_BIN" "$INPUT" "$OUTPUT" editable-pptx

unzip -t "$OUTPUT" >/dev/null
unzip -q "$OUTPUT" -d "$WORK_DIR"
xmllint --noout \
  "$WORK_DIR/ppt/presentation.xml" \
  "$WORK_DIR/ppt/slides/slide1.xml" \
  "$WORK_DIR/[Content_Types].xml"

match_count() {
  local pattern="$1"

  if command -v rg >/dev/null 2>&1; then
    rg -o "$pattern" "$WORK_DIR/ppt/slides" | wc -l | tr -d ' '
  else
    grep -RhoE "$pattern" "$WORK_DIR/ppt/slides" | wc -l | tr -d ' '
  fi
}

shape_count="$(match_count '<p:sp[ >]')"
text_count="$(match_count '<a:t>')"
picture_count="$(match_count '<p:pic')"
page_count="$(find "$WORK_DIR/ppt/slides" -maxdepth 1 -name 'slide*.xml' | wc -l | tr -d ' ')"

if [[ "$page_count" -lt 1 || "$shape_count" -lt 10 || "$text_count" -lt 10 ]]; then
  echo "Editable PPTX object check failed: pages=$page_count shapes=$shape_count text=$text_count pictures=$picture_count" >&2
  exit 1
fi

if command -v qlmanage >/dev/null 2>&1; then
  qlmanage -t -s 1200 -o "$QL_DIR" "$OUTPUT" >/dev/null 2>&1
  if ! find "$QL_DIR" -maxdepth 1 -type f -name '*.png' | grep -q .; then
    echo "Quick Look did not produce a PPTX preview." >&2
    exit 1
  fi
fi

echo "Editable PPTX export OK: pages=$page_count shapes=$shape_count text=$text_count pictures=$picture_count"
echo "$OUTPUT"
