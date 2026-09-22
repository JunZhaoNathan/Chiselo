# Chiselo 0.1.27

Chiselo 0.1.27 hardens the existing-HTML editing workflow around stable, local
changes.

## What changed

- Text editing now locks the active object's local frame and the canvas view
  while characters are entered. Selection geometry, zoom, and unrelated
  neighbors remain stable until editing finishes.
- Exiting text editing performs one consolidated layout settlement, keeping
  the final source, diagnostics, and selection state in sync.
- The public product preview now documents the three-page workflow: editor
  home, object inspector, stable text editing, and image replacement.
- Image replacement remains available from the selected `<img>` object and
  supports local image data without rebuilding unrelated HTML nodes.

## Verification

- Swift build and unit tests.
- WebKit direct HTML edit isolation and mutation-throttle tests.
- Per-character text geometry stability: target, selection box, canvas view,
  and an unrelated sibling are compared before and after typing.
- Signed Developer ID package with Apple notarization and stapled ticket.
- Sparkle appcast and R2 incremental update feed for build 27.
