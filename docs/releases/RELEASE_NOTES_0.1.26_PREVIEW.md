# Chiselo 0.1.26

This preview improves direct HTML editing precision and containment.

- HTML and body roots are structural only and cannot be selected, edited, moved, duplicated, arranged, or deleted.
- Parent, child, and sibling navigation skips hidden, runtime, and non-editable nodes.
- Text editing preserves the local frame and reports overflow through diagnostics without moving neighboring modules.
- Canvas dimensions invalidate on real element insertion/removal, allowing page shrink after deletion without text-edit reflow drift.
- Responsive preview changes apply in one synchronous layout pass and retain CSS breakpoint behavior.
- Insert, replace, and add-image workflows remain covered by real WKWebView acceptance tests.
