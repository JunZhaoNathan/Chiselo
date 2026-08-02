# Chiselo 0.1.16 Preview

Chiselo 0.1.16 strengthens the existing-HTML visual editing workflow around its two hardest promises: a local edit must not disturb unrelated page regions, and untrusted HTML must not silently gain network or runtime privileges.

## Highlights

- Local text, typography, line-height, and padding edits preserve the selected object's current frame so sibling modules and following sections stay still.
- Overflow becomes an explicit review item instead of pushing unrelated content.
- Automatic frame preservation is shown as local stability protection rather than ordinary inline-style pollution, and reverting the text change removes that protection too.
- Static-safe mode now blocks remote HTTP/HTTPS documents, images, styles, scripts, fonts, media, SVG documents, and raw requests with native WebKit content rules.
- Imported pages cannot navigate the main WebView away from the Chiselo editor shell.
- Trusted dynamic compatibility still supports scripts, forms, and remote resources after explicit confirmation.
- SwiftPM now exposes a formal `ChiseloTests` XCTest target for transactional save and runtime-policy regressions.
- Delivery-check views, visual snapshot types, and safe-runtime HTML transforms were moved out of the largest source files without changing UI structure.

## Verification

- `swift build`
- `swift test` with 7 passing XCTest cases
- Runtime script/form isolation and trusted opt-in regression
- Zero-collateral local edit regression
- Real-case zero-collateral checks against the sample page, operations dashboard, editorial brief, and delivery form
- Visual-change regression confirming protected export, clean editor metadata, and full source-style restoration after rollback
- Exact untouched-source and clean-export regression
- Local stylesheet writeback and HTML/CSS rollback regressions
- Complete release preflight

This is source metadata and preview documentation only. No package, notarization, publication, or hot-update activation is implied.
