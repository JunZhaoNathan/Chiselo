# Chiselo 0.1.20 Preview

Chiselo 0.1.20 makes the native editor bridge smaller and more reliable while preserving the high-zoom editing contract introduced in 0.1.19. Browser selection payloads are now decoded by a stateless component, and the Inspector receives the complete rendered box-model, layout, position, opacity, typography, and stylesheet-writeback state that the HTML editor already reports.

## Highlights

- Bridge decoding is isolated from `EditorModel` state ownership, reducing the chance that future message-format work disturbs document, gesture, or save behavior.
- Required element geometry rejects missing, invalid, or non-finite values before it can enter the native selection model.
- Optional nested source items tolerate malformed entries while preserving valid siblings.
- The Inspector now receives previously omitted computed fields such as padding, margin, display, flex settings, overflow, opacity, and letter spacing.
- Complete and malformed bridge payloads are covered by focused XCTest cases.
- High-zoom drag, resize, cross-frame pointer release, zoom preservation, zoom-out selection stability, and non-target zero-collateral checks pass on four real HTML pages.

## Scope

This preview targets existing static HTML and conventional AI-generated HTML. Complex dynamic applications still require explicit trusted compatibility mode, and cross-origin resources remain subject to browser security boundaries.

This source version has not been signed, notarized, uploaded, or published.
