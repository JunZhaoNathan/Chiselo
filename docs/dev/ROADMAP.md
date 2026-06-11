# Roadmap

## Product Direction

Chiselo should become an HTML layout operating layer for AI-generated visual documents.

The core idea:

- HTML remains the real source document.
- Browser rendering is used as the truth for what the user sees.
- Chiselo builds object-level controls on top of that rendered result.
- Exports are compiler targets: HTML, PDF, PPTX, and future formats.

## Near Term

- Improve hover actions for images, text, tables, cards, and grouped objects.
- Add visible rulers and measurement readouts.
- Improve snapping, alignment guides, and distribution controls.
- Add visual save preview and diff before overwriting original HTML.
- Add a visual history browser for `.chiselo-history/` snapshots.
- Strengthen table row/column editing for complex merged cells.
- Improve SVG detection and export fallback.

## Medium Term

- Better layout freezing for responsive pages.
- Page/slide boundary detection for AI-generated HTML.
- More reliable object grouping and ungrouping.
- Layer panel with drag-to-reorder.
- Export QA report explaining what could and could not map to editable PPTX.

## Long Term

- AI-assisted repair actions for overflow, overlap, spacing, alignment, and consistency.
- Plugin system for import repair, export QA, table tools, and PPTX compilation.
- Higher-fidelity object-editable PPTX compiler.
- Safer sandboxing for untrusted HTML.
