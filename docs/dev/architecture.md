# Architecture

Chiselo should behave like a native macOS app while keeping browser-grade HTML rendering.

Slogan: **Chisel your HTML**.

Positioning: **HTML finishing and delivery + object-level visual refinement + multi-format output**.

## Product Shape

```text
Existing or generated HTML
  -> SwiftUI macOS editor
  -> WKWebView precise canvas
  -> Object-level visual refinement
  -> HTML / PDF / PNG / PPTX output
```

## Layers

- SwiftUI app shell: windows, menus, file panels, inspector, shortcuts, native document behavior.
- WKWebView editor: canvas rendering, selection overlay, drag, resize, snap, undo, redo, text editing.
- Direct HTML editor: loads arbitrary HTML into an iframe, edits rendered objects, and serializes the modified document.
- Structured layout schema: optional internal mode for fixed-canvas precision editing.
- Exporters: HTML remains the editable source document; PDF/PNG/PPTX are delivery targets.
- Generated HTML workflows: generated HTML is one useful source that Chiselo can polish, inspect, and export.

## Design Principles

- Keep all element coordinates in canvas space, not viewport space.
- Preview zoom must not change stored coordinates.
- Treat HTML as the editable source document.
- Edit the original document directly where possible and write changes as inline styles/content mutations.
- Complex imported HTML can also be converted to a fixed-canvas layout when the user wants stable precision control.
- Every edit should be representable as a command for undo/redo.
- Prefer predictable layout boxes when the user chooses fixed-canvas precision editing.

## Near-Term Roadmap

1. Add multi-slide support and real thumbnails.
2. Add more element types: image, line, ellipse, chart placeholder, code block.
3. Improve text editing: font panel, color controls, overflow modes.
4. Add multi-select, grouping, distribution, rulers, and keyboard nudging.
5. Add schema validation in the app before save/export.
6. Add clearer object structure selection and breadcrumbs for Direct HTML mode.
7. Add PDF/PNG export.
8. Add PPTX export mapping.
