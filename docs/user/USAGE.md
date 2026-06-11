# Usage Guide

## Open HTML

Use the Open button or drag a `.html`, `.htm`, or `.xhtml` file into the Chiselo window. You can also drag a file onto `Chiselo.app` in Finder.

Each document opens in a browser-style tab.

## Select And Edit

- Click rendered HTML content to select an element.
- Double-click text-like elements to edit text in place.
- Use the left object structure only when nested objects are hard to click. Chiselo labels common AI-generated HTML parts as page, title, image, table, card, module, and cell so you can work from the rendered document instead of reading raw DOM tags.
- Use Shift/Cmd-click for multi-select.
- Press arrow keys to nudge selected objects.
- Hold Shift with arrow keys for larger nudges.
- Use Command + mouse wheel to zoom.

## Layout Modes

`Free` mode writes absolute positioning and gives HTML an Office-like direct layout editing feel.

`Transform` mode writes `transform: translate(...)` and is gentler when preserving the original document flow matters.

Chiselo shows detected page or slide boundaries on the canvas with center reference lines and ruler ticks. Dragging or resizing objects can snap to the detected page edges and center lines for more precise page-level adjustment.

For repeated HTML objects, use `子对象` or `同类` in the `精修` panel to select multiple objects, then use `同宽`, `同高`, `横等距`, or `纵等距` in `对齐` to make card, image, metric, and module groups consistent.

## Safe Saving

When opening a real local HTML or Chiselo deck file, Chiselo creates a one-time sibling backup named like `filename.chiselo-backup.html` or `filename.chiselo-backup.aislide`. If that backup already exists, Chiselo keeps it instead of replacing it.

When saving over an existing HTML or deck file, Chiselo first copies the previous version into a sibling `.chiselo-history/` folder with a timestamped filename. Use the `备份` toolbar button to reveal that folder from the current document.

Use the `恢复` toolbar button to restore the newest snapshot. Chiselo asks for confirmation and saves the current file into `.chiselo-history/` before restoring.

## Images

Select an image and use the replace image action. Chiselo embeds the replacement as a data URL so exported HTML remains portable.

## Tables

Select a table, row, or cell to reveal row/column actions. Chiselo handles simple tables and includes extra protection for merged cells.

## Delivery Check

The left sidebar flags delivery risks such as broken resources, temporary editor markers, complex tables, SVG usage, text overflow, out-of-bounds elements, and obvious overlaps. When a risk points to a real HTML element, click it to select that element on the canvas.

## Freeze Layout

Freeze Layout converts the current rendered HTML into a structured editable Chiselo tab. This is useful when an HTML page, document, poster, dashboard, or slide-style page should behave like a fixed visual canvas for precise Office-like adjustment.

## Export

- HTML: clean edited document with Chiselo temporary attributes removed.
- PDF: high-fidelity visual final output.
- PPTX: best-effort object-editable delivery file.

PDF is the fidelity fallback when a delivery format cannot represent a CSS effect as editable objects.
