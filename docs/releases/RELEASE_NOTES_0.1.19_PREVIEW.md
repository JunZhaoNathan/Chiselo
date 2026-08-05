# Chiselo 0.1.19 Preview

Chiselo 0.1.19 strengthens stable precision editing while the imported HTML canvas is zoomed. The selected object can move and resize at high zoom without changing the zoom level, shifting unrelated layout, or leaving a gesture active after the pointer crosses out of the HTML frame.

## Highlights

- Flow-managed elements now resize with local transform scaling. Their original layout footprint stays fixed, so adjacent cards, parent containers, and following sections do not move when only the selected object is resized.
- High-zoom drag and resize coordinates are translated from screen space back into HTML document space and checked against the requested document-space delta.
- Pointer release is handled across the HTML frame and editor shell, preventing sticky drag or resize gestures after the pointer leaves the page.
- Zooming back out preserves the edited object's selection and geometry and does not alter unrelated objects.
- Geometry edits now pass the same zero-collateral contract as text and style edits: complete computed styles, pseudo-element styles, geometry, and comparable DOM source remain unchanged for non-target objects.
- The sample page, operations dashboard, editorial brief, and delivery form all run through the strengthened zoom and geometry regression in release preflight.

## Scope

This preview targets existing static HTML and conventional HTML. Complex dynamic applications still require explicit trusted compatibility mode, and cross-origin resources remain subject to browser security boundaries.

This source version has not been signed, notarized, uploaded, or published.
