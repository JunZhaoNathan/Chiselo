# Roadmap

## Product Direction

Chiselo should become an HTML finishing and delivery layer for visual documents.

The core idea:

- HTML remains the editable source document.
- Browser rendering is used as the truth for what the user sees.
- Chiselo builds object-level controls on top of that rendered result.
- Export checks and compiler targets focus on delivery quality: HTML, PDF, PPTX, and future formats.
- Chiselo should not drift toward Dreamweaver, website building, template authoring, AI content generation, or code-first editing.

## Near Term

- Improve hover actions for images, text, tables, cards, and grouped objects.
- Add group-internal alignment, equal spacing, and size matching for captured modules.
- Add visual save preview and diff before overwriting original HTML.
- Strengthen table row/column editing for complex merged cells.
- Improve SVG detection and export fallback.

## Medium Term

- Better layout freezing for responsive pages.
- More reliable object grouping and ungrouping.
- Layer panel with drag-to-reorder.
- Export QA report explaining what could and could not map to editable PPTX.
- More precise spacing and repeated-module consistency controls.

## Recently Landed

- Page/canvas boundary detection for HTML documents.
- Visible page boundaries, center references, ruler ticks, snapping guides, and distribution controls.
- Export preflight with HTML/PDF readiness and PPTX editability scoring.
- Visual history browser for `.chiselo-history/` snapshots.
- Deterministic Layout IR conversion for stable precision editing.
- Module grouping and module-group movement for converted editable versions.
- Non-technical style controls for typography, color, alignment, borders, radius, shadows, and image display modes.
- PPTX effect-risk preflight for complex CSS visuals before export.

## Long Term

- Rule-based repair actions for overflow, overlap, spacing, alignment, and consistency.
- Plugin system for import repair, export QA, table tools, and PPTX compilation.
- Higher-fidelity object-editable PPTX compiler.
- Safer sandboxing for untrusted HTML.
