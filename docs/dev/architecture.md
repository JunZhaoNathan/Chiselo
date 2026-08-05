# Architecture

Chiselo should behave like a native macOS app while keeping browser-grade HTML rendering.

Slogan: **Chisel your HTML**.

Positioning: **A focused visual editor for existing HTML, with object-level refinement, protected save, and reliable delivery**.

## Product Shape

```text
Existing HTML
  or an HTML page produced by another tool
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
- Runtime conversion workflow: complex or script-rendered HTML can be converted to a fixed-canvas precision-editing version when direct editing is not stable enough.
- Document lifecycle: tabs independently track original source, current source, linked CSS changes, runtime mode, and unsaved state; close and quit decisions pass through one protected workflow.
- Save coordinator: HTML and changed local stylesheets are validated, staged, snapshotted, committed, and automatically rolled back as one transaction.
- Runtime security: static-safe mode combines inert page scripts with native WebKit network and navigation rules. PDF and PPTX rendering preserve that safe default; trusted compatibility removes those restrictions only after confirmation.
- Editor runtime modules: runtime safety, source-node mapping, visual-change classification, and numeric geometry primitives are loaded before the main editor runtime through explicit frozen browser APIs, keeping security, source preservation, snapshot comparison, and geometry calculations independent from shared canvas state. DOM capture, diagnostic orchestration, gesture state, and revert execution remain in the main runtime where editor state is owned.
- UI layers: ordinary mode exposes visual content/style/layout tasks; advanced mode adds structure, source, runtime, layering, and professional export controls.
- Responsive viewport: desktop/tablet/mobile preview changes iframe layout width only and never becomes document state.

## Design Principles

- Keep all element coordinates in canvas space, not viewport space.
- Preview zoom must not change stored coordinates.
- Treat HTML as the editable source document.
- Return the exact original source when no edit occurred; serialize the DOM only after a real document mutation.
- Run imported scripts only after explicit trusted-document opt-in.
- A local content or visual-style edit must not move, resize, or restyle unselected modules; preserve the target frame and report overflow instead of reflowing unrelated content.
- Edit the original document directly where possible and write changes as inline styles/content mutations.
- Complex imported HTML can also be converted to a fixed-canvas layout when the user wants stable precision control.
- Every edit should be representable as a command for undo/redo.
- Prefer predictable layout boxes when the user chooses fixed-canvas precision editing.

## Current Boundaries

- Chiselo edits files; it does not create or manage a website project.
- Static and conventional HTML are the primary compatibility target.
- Arbitrary framework applications, cross-origin embedded content, animation timelines, server code, databases, FTP/SFTP publishing, and full IDE code intelligence are outside the light editor scope.
- PDF is the fidelity target; editable PPTX is a best-effort compiler target.
