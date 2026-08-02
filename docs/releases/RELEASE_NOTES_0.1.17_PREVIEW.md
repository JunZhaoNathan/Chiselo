# Chiselo 0.1.17 Preview

Chiselo 0.1.17 continues the existing-HTML editing work with a stricter rule: editing one selected object must not modify the live DOM source of any unrelated object, even when the rendered page appears unchanged.

## Highlights

- Zero-collateral regression now compares unrelated objects' DOM source as well as position, size, color, background, and transform.
- The stricter check passes the synthetic grid fixture and four bundled real HTML pages: sample page, operations dashboard, editorial brief, and delivery form.
- HTML diagnostic score and recommendation calculations now live in an independent presentation module.
- File encoding detection and open-document parsing now live outside the main editor state model.
- Source-node matching and stable object-ID preservation now run through an independent editor runtime module.
- Visual-change filtering, classification, review summaries, writeback labeling, and rollback eligibility now run through a separate pure runtime module; DOM reads and writes remain owned by the main editor.
- An unused open-result helper was removed.

## Verification

- `swift build`
- `swift test` with 7 passing XCTest cases
- Synthetic zero-collateral edit regression
- Four real-case zero-collateral regressions with DOM source identity checks
- Source replacement, child-ID preservation, mapping preview, undo, and clean-export integration regression
- Visual-change filter, existing-object rollback, and added-object rollback regressions
- Complete release preflight

This is source metadata and preview documentation only. No package, signing, notarization, publication, or hot-update activation is implied.
