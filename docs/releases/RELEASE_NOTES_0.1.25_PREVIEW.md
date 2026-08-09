# Chiselo 0.1.25

This release focuses on selection isolation, document safety, and reliable
delivery of the current editor fixes.

- Selecting, moving, resizing, or editing one object no longer changes
  unrelated objects.
- HTML opens at its original 100% CSS-pixel scale. Window and inspector changes
  do not trigger automatic zoom.
- Editable-layout conversion captures each text fragment once, eliminating
  duplicated text objects in nested HTML.
- Save, export, and editable-layout conversion stay bound to the tab that
  started the operation. Tab switching and closing remain disabled until the
  operation finishes.
- A failed editable-layout conversion leaves the source tab and its unsaved
  state unchanged.
- History restore now uses atomic replacement and rollback to preserve the
  current file if restoration fails.
- Repeated editable HTML export replaces the existing Chiselo runtime instead
  of accumulating duplicate style and script blocks.
- The complete zoomed canvas interaction gate now runs reliably in WebKit and
  continues to verify high-zoom drag and resize geometry.
- Release download URLs include the exact build fingerprint, preventing stale
  CDN bytes from being served for a regenerated artifact.

This Apple Silicon macOS package uses version `0.1.25` and Sparkle build `25`,
allowing existing `0.1.24` users to receive the update normally.
