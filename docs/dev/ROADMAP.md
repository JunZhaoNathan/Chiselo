# Roadmap

## Product Direction

Chiselo should become an HTML finishing and delivery layer for visual documents.

The core idea:

- HTML remains the editable source document.
- Browser rendering is used as the truth for what the user sees.
- Chiselo builds object-level controls on top of that rendered result.
- Export checks and compiler targets focus on delivery quality: HTML, PDF, PPTX, and future formats.

## Near Term

- Improve hover actions for images, text, tables, cards, and grouped objects.
- Add visual save preview and diff before overwriting original HTML.
- Strengthen table row/column editing for complex merged cells.
- Improve SVG detection and export fallback.

## Medium Term

- Better layout freezing for responsive pages.
- More reliable object grouping and ungrouping.
- Layer panel with drag-to-reorder.
- Export QA report explaining what could and could not map to editable PPTX.

## Recently Landed

- Page/canvas boundary detection for HTML documents.
- Visible page boundaries, center references, ruler ticks, snapping guides, and distribution controls.
- Export preflight with HTML/PDF readiness and PPTX editability scoring.
- Visual history browser for `.chiselo-history/` snapshots.

## Long Term

- Rule-based repair actions for overflow, overlap, spacing, alignment, and consistency.
- Plugin system for import repair, export QA, table tools, and PPTX compilation.
- Higher-fidelity object-editable PPTX compiler.
- Safer sandboxing for untrusted HTML.
