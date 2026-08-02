# Product Position Review

## Core Position

Chiselo is built to replace Dreamweaver's existing-HTML visual editing workflow for the AI HTML era, without copying Dreamweaver's site-building, FTP, or traditional IDE surface.

It starts from an existing HTML file. The job is to make that file easier to inspect, adjust, polish, and deliver with high visual fidelity.

## Product Promise

- Static pages and conventional AI-generated HTML must be simpler to edit than in Dreamweaver.
- Source preservation, save safety, and change review must be more reliable and more visible to the user.
- Complex dynamic pages must enter an explicit trusted compatibility mode instead of silently weakening the default safety boundary.
- Existing HTML remains the product's input and source of truth; Chiselo does not require a proprietary project model before editing can begin.

## What Chiselo Is

- A visual finishing surface for existing HTML pages and visual documents.
- A precision adjustment tool for text, images, tables, cards, modules, spacing, alignment, and page boundaries.
- A delivery preflight tool for clean HTML, high-fidelity PDF, and best-effort editable PPTX.
- A safer editing workflow with backups, version snapshots, diagnostics, and restore paths.
- A nontechnical visual editor for mature HTML produced by AI or other tools.

## What Chiselo Is Not

- Not the full Dreamweaver IDE, site manager, or publishing stack.
- Not a website builder.
- Not a template marketplace.
- Not an AI content generator.
- Not a prompt-to-page app.
- Not a code-first IDE.

## Current Feature Alignment

Strongly aligned:

- Direct HTML opening and rendered-object selection.
- In-place text editing.
- Image replacement with portable embedded resources.
- Table editing.
- Geometry controls, page/canvas boundaries, guides, snapping, and nudging.
- Flow-preserving local resize plus zoom-stable pointer coordinates and cross-frame gesture release.
- Non-technical visual style controls for color, typography, alignment, borders, radius, shadows, and image display modes.
- Delivery preflight for broken resources, overflow, out-of-bounds objects, overlap, clean HTML, PDF, and PPTX risks.
- PPTX effect-risk detection for complex CSS visuals that need post-export review.
- Object-level visual diff against the opened HTML for reviewing changed text, images, geometry, and key styles before delivery, including next/previous changed-object navigation in export preflight.
- PPTX editable-object report for estimating text, image, shape, review, and whole-object fallback counts before export, with click-through targeting, next/previous review navigation, and preflight repair actions.
- Safe backups and history restore.
- Protected close/quit, transactional HTML plus local CSS save, and exact untouched-source round-trip.
- Ordinary/advanced UI separation and exact responsive viewport previews.
- Static-safe HTML loading with explicit trusted dynamic compatibility.
- `转为可编辑版` for converting the current rendering into stable editable objects.
- Deterministic module grouping, module-group movement, and module-internal size/spacing cleanup.

Needs continued polishing:

- More advanced group-internal alignment rules for mixed text/image/button modules.
- More predictable resizing and layout preservation for responsive pages.
- Broader spacing and style consistency controls across mixed modules and repeated cards.
- Higher-fidelity editable PPTX compiler behavior for complex tables, SVG, effects, and layered objects.
- One-click repair actions that can modify or simplify risky objects, not only locate them.
- Pixel-level screenshot diff and richer before/after review before overwriting files.

## Language Guardrails

Use:

- existing HTML;
- replaces Dreamweaver's existing-HTML visual editing workflow;
- HTML refinement;
- high-fidelity adjustment;
- visual finishing;
- delivery preflight;
- source preservation;
- safe save and change review;
- trusted compatibility mode;
- dynamic-content risk;
- script-rendered HTML;
- convert to editable version.

Avoid as product identity:

- AI;
- generated HTML;
- generator compatibility;
- website builder;
- full Dreamweaver replacement;
- code editor.

Always qualify the Dreamweaver comparison by naming the workflow being replaced. Existing and AI-generated HTML are both first-class inputs. Dynamic applications remain a trusted compatibility case rather than the default workflow.

## Next Product Priorities

1. Formal regression coverage for source preservation, save rollback, and visual editing behavior.
2. Native isolation for untrusted HTML and an explicit trusted compatibility path for dynamic pages.
3. Minimal-diff source writeback and richer before/after review before overwriting files.
4. More predictable resizing, spacing, and layout preservation across responsive pages and repeated modules.
5. Continued decomposition of the SwiftUI interface, document model, and browser editor runtime into independently tested modules.
