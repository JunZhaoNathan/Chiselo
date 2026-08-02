# Chiselo 0.1.18 Preview

Chiselo 0.1.18 tightens the zero-collateral editing contract for existing and conventional AI-generated HTML: a local text or style edit is now checked against the complete computed visual state and DOM source of visible non-target objects.

## Highlights

- Isolation regressions compare all computed CSS properties rather than a short representative list.
- `::before` and `::after` pseudo-element styles are included so generated decoration cannot change unnoticed.
- Up to 120 visible non-target nodes are checked per page, including layout ancestors and unrelated descendant objects where source can be compared independently.
- The stronger invariant passes the synthetic fixture, sample page, operations dashboard, editorial brief, and delivery form.
- Numeric resize, snap, distance, rectangle, and overflow logic now lives in an independently tested editor runtime module.
- Gesture ownership and all DOM mutations remain in the main runtime to keep this refactor behavior-neutral.

## Verification

- Focused geometry boundary tests
- Swift build and packaged-resource inspection
- Canvas interaction, drag smoothness, precision editing, table geometry lock, and diagnostics regressions
- Synthetic and four real-case zero-collateral regressions
- Complete release preflight

This is source metadata and preview documentation only. No package, signing, notarization, publication, or hot-update activation is implied.
