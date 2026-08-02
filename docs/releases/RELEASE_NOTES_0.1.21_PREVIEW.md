# Chiselo 0.1.21 Preview

This preview fixes an editing-contract regression in imported HTML pages.

- HTML now opens at 100% CSS-pixel scale and does not automatically zoom when the app window, inspector, selection, local edit, or responsive preview changes.
- `100%` and `fit width` are explicit toolbar actions; Cmd/Ctrl plus wheel remains available for manual zoom.
- Table cells keep their protective geometry lock, while the inspector now presents working text, whole-table, row/column, alignment, and cell-style actions instead of controls that cannot safely apply.
- The release was checked in real WebKit against the complex delivery-form HTML page, including zoom stability and zero-collateral local edits.
- The local preview bundle now launches correctly on macOS when it uses ad-hoc signing, including the bundled Sparkle update framework.
