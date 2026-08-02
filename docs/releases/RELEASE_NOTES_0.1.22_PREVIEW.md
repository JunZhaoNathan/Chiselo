# Chiselo 0.1.22 Preview

This patch fixes a visible selection-alignment defect in imported HTML.

- In responsive previews, selection boxes now stay on the element a user clicked even after the embedded page has scrolled.
- The correction affects only the editor overlay. It does not modify the imported HTML, computed styles, layout, or exported source.
- The release checks a real form input in WebKit at 768px, including embedded scrolling and screen-edge alignment.
