# Usage Guide

## Open HTML

Use the Open button or drag a `.html`, `.htm`, or `.xhtml` file into the Chiselo window. You can also drag a file onto `Chiselo.app` in Finder.

Each document opens in a browser-style tab.

## Select And Edit

- Click rendered HTML content to select an element.
- Double-click text-like elements to edit text in place.
- Use the left object structure only when nested objects are hard to click. Chiselo labels common HTML parts as page, title, image, table, card, module, and cell so you can work from the rendered document instead of reading underlying tags.
- Use Shift/Cmd-click for multi-select.
- Press arrow keys to nudge selected objects.
- Hold Shift with arrow keys for larger nudges.
- Use Command + mouse wheel to zoom.

## Layout Modes

`Free` mode writes fixed positioning and gives HTML a direct visual layout editing feel.

`Transform` mode writes `transform: translate(...)` and is gentler when preserving the original document flow matters.

Chiselo shows detected page or canvas boundaries with center reference lines and ruler ticks. Dragging or resizing objects can snap to the detected page edges and center lines for more precise page-level adjustment.

For repeated HTML objects, use `子对象` or `同类` in the `精修` panel to select multiple objects, then use `同宽`, `同高`, `横等距`, or `纵等距` in `对齐` to make card, image, metric, and module groups consistent.

When an object is selected, the `几何` panel shows its distance to the current page/canvas edges and its center offset. Use `复制几何` to copy position, size, margins, and center offset for before/after review.

## Visual Style

Use the `样式` panel to adjust selected objects without editing CSS. Text objects expose font size, weight, line height, color swatches, exact color values, and left/center/right alignment.

Use `外观` for fill, border color, border width, corner radius, and shadow presets. These controls apply to direct HTML selections and to objects created by `转为可编辑版`.

When an image is selected, use `显示方式` to choose `裁切`, `完整`, or `拉伸`, then replace the image if needed. Chiselo writes these choices back into the exported HTML instead of keeping them as editor-only state.

## Safe Saving

When opening a real local HTML or Chiselo project file, Chiselo creates a one-time sibling backup named like `filename.chiselo-backup.html` or `filename.chiselo-backup.aislide`. If that backup already exists, Chiselo keeps it instead of replacing it.

When saving over an existing HTML or Chiselo project file, Chiselo first copies the previous version into a sibling `.chiselo-history/` folder with a timestamped filename. Use the `备份` toolbar button to reveal that folder from the current document.

Use the `恢复` toolbar button to open the version history browser. Select any snapshot to see its timestamp, filename, and file size, then restore that specific version. Chiselo asks for confirmation and saves the current file into `.chiselo-history/` before restoring.

## Images

Select an image and use the replace image action. Chiselo embeds the replacement as a data URL so exported HTML remains portable.

## Tables

Select a table, row, or cell to reveal row/column actions. Chiselo handles simple tables and includes extra protection for merged cells.

## Delivery Check

The left sidebar flags delivery risks such as broken resources, temporary editor markers, complex tables, SVG usage, text overflow, out-of-bounds elements, and obvious overlaps. When a risk points to a real HTML element, click it to select that element on the canvas.

Some HTML pages are script-rendered rather than plain static documents. Chiselo flags these as dynamic-content risks when it sees script-built content, embedded pages, canvas regions, external runtime files, or transparent layers that block selection. If the page is difficult to edit as separate objects, use `转为可编辑版` to turn the current rendering into a stable object version before final adjustment.

Use `导出` > `导出预检` before final delivery. The preflight panel scores HTML readiness, PDF fidelity, and PPTX editability, then lists the issues that should be fixed before export or reviewed after PPTX export.

Chiselo also shows an object-level visual diff against the file as it looked when opened. It tracks changed text, images, position, size, and key visual styles so you can review what actually changed before delivery.

For PPTX, the preflight panel shows a `PPTX 可编辑对象` report. It estimates how many visible objects can remain as editable text, images, and simple shapes, and separates objects that need manual review or may have to stay as whole-object fallbacks. Click a non-zero count to jump to the first matching object before export.

For PPTX, Chiselo also flags complex visual effects such as background images, radial or repeating gradients, filters, masks, clipping paths, blend modes, and 3D transforms. These effects can still look correct in HTML/PDF, but they need extra review when the goal is an editable PowerPoint file.

## Editable Version

`转为可编辑版` converts the current rendered HTML into a fixed-canvas Chiselo tab backed by a deterministic Layout IR. Text becomes editable text objects, images become replaceable image objects, and computed visual boxes become adjustable shapes. Embedded pages, canvas regions, and other content that cannot be safely decomposed are kept as whole-object fallbacks with clear editability notes.

After conversion, the left sidebar and export preflight show an editable-version quality summary with direct-editable object counts, fallback counts, and PPTX editability. Captured cards, sections, tables, and visual modules also keep module membership metadata so related objects can be reviewed together.

When you select an object that belongs to a captured module, use `选择模块` in the Inspector to select the whole module. The module can then be moved, nudged with arrow keys, aligned, snapped, duplicated, deleted, or locked as one unit while its internal text, image, and shape objects remain editable.

With the module selected, use `同宽`, `同高`, `横等距`, and `纵等距` to clean up internal card, metric, button, or image spacing without editing code.

## Export

- HTML: clean edited document with Chiselo temporary attributes removed.
- PDF: high-fidelity visual final output.
- PPTX: best-effort object-editable delivery file.

PPTX preflight highlights merged tables, SVG/vector graphics, object overlap, overflow, and missing resources because those areas most often need manual review in PowerPoint.

PDF is the fidelity fallback when a delivery format cannot represent a CSS effect as editable objects.
