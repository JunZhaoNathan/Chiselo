# Roadmap

## Product Direction

Chiselo should replace Dreamweaver's existing-HTML visual editing workflow for the AI HTML era. It should not reproduce Dreamweaver's site-building, FTP, or traditional IDE surface.

The core idea:

- HTML remains the editable source document.
- Browser rendering is used as the truth for what the user sees.
- Chiselo builds object-level controls on top of that rendered result.
- Export checks and compiler targets focus on delivery quality: HTML, PDF, PPTX, and future formats.
- Chiselo should cover the high-value visual editing loop associated with Dreamweaver without inheriting full IDE complexity.
- Chiselo accepts existing and AI-generated HTML; it does not generate sites, scaffold projects, manage servers, or become a code-first IDE.
- Static and conventional AI-generated HTML should be simpler to edit than in Dreamweaver.
- Source preservation, save safety, and change review should be more reliable and explicit.
- Complex dynamic pages should use a clearly disclosed trusted compatibility mode.

## Near Term

- Improve hover actions for images, text, tables, cards, and grouped objects.
- Preserve undo/redo history across tab switches.
- Add group-internal alignment, equal spacing, and size matching for captured modules.
- Add richer screenshot-based before/after preview before overwriting original HTML.
- Strengthen table row/column editing for complex merged cells.
- Improve SVG detection and export fallback.
- Add deeper one-click repair actions for tables, vectors, effects, and whole-object fallbacks.

## Medium Term

- Better layout freezing for responsive pages.
- Optional custom viewport widths and side-by-side responsive comparison.
- More reliable object grouping and ungrouping.
- Layer panel with drag-to-reorder.
- Deeper PPTX compiler improvements for complex tables, SVG/vector graphics, effects, and layered objects.
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
- Object-level visual diff v1 against the opened HTML.
- Visual-change review navigation in export preflight for stepping through changed objects before delivery.
- PPTX editable-object report v1 before export, including first-object click-through targeting and next/previous object review navigation.
- PPTX preflight repair-action panel for locating risky objects, converting to editable version, and choosing PDF for high-fidelity fallback.
- Flow-preserving local resize and high-zoom pointer regressions across four representative real HTML layouts.

## Long Term

- Rule-based repair actions for overflow, overlap, spacing, alignment, and consistency.
- Plugin system for import repair, export QA, table tools, and PPTX compilation.
- Higher-fidelity object-editable PPTX compiler.
- Safer sandboxing for untrusted HTML.
- Further decomposition of the SwiftUI inspector, document lifecycle model, and browser editor runtime into independently tested modules.
