#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d /tmp/chiselo-pptx-design.XXXXXX)"
EXPORT_BIN="$WORK_DIR/chiselo-export"
INPUT="$WORK_DIR/design-absorption.html"
OUTPUT="$WORK_DIR/design-absorption.pptx"
UNZIP_DIR="$WORK_DIR/unzipped"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$INPUT" <<'HTML'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    html, body { margin: 0; background: #fff; }
    .slide {
      position: relative;
      width: 960px;
      height: 540px;
      overflow: hidden;
      background: linear-gradient(135deg, #f8fbff 0%, #dbeafe 46%, #ffffff 100%);
      font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
    }
    .card {
      position: absolute;
      left: 86px;
      top: 82px;
      width: 620px;
      height: 270px;
      padding: 38px;
      border-radius: 28px;
      background: linear-gradient(120deg, #ffffff 0%, #eef6ff 100%);
      box-shadow: 0 24px 52px rgba(15, 23, 42, 0.22);
      border: 1px solid rgba(10, 132, 255, 0.22);
    }
    .card::before {
      content: "BETA";
      position: absolute;
      right: 28px;
      top: 24px;
      padding: 7px 12px;
      border-radius: 999px;
      background: #0a84ff;
      color: white;
      font-size: 15px;
      font-weight: 800;
    }
    h1 { margin: 0 0 20px; font-size: 54px; line-height: 1.02; color: #111827; }
    p { margin: 0; width: 470px; font-size: 24px; line-height: 1.3; color: #334155; }
  </style>
</head>
<body>
  <section class="slide">
    <div class="card">
      <h1>Native PPTX Design</h1>
      <p>Gradients, shadows, and pseudo-element labels should become PowerPoint-native objects.</p>
    </div>
  </section>
</body>
</html>
HTML

swiftc "$ROOT_DIR/Chiselo/HTMLRenderExporter.swift" "$ROOT_DIR/scripts/export-html-high-fidelity.swift" -o "$EXPORT_BIN"
"$EXPORT_BIN" "$INPUT" "$OUTPUT" editable-pptx

unzip -q "$OUTPUT" -d "$UNZIP_DIR"

contains() {
  if command -v rg >/dev/null 2>&1; then
    rg -q "$1" "$2"
  else
    grep -qE "$1" "$2"
  fi
}

if ! contains '<a:gradFill' "$UNZIP_DIR/ppt/slides/slide1.xml"; then
  echo "Missing native gradient fill in editable PPTX." >&2
  exit 1
fi

if ! contains '<a:outerShdw' "$UNZIP_DIR/ppt/slides/slide1.xml"; then
  echo "Missing native shadow in editable PPTX." >&2
  exit 1
fi

if ! contains 'BETA' "$UNZIP_DIR/ppt/slides/slide1.xml"; then
  echo "Missing pseudo-element text in editable PPTX." >&2
  exit 1
fi

echo "PPTX design absorption OK: native gradients, shadows, and pseudo-elements found."
