# Chiselo Material UI Review

Slogan: **Chisel your HTML**.

Positioning: **HTML finishing and delivery + object-level visual refinement + multi-format output**.

## Reference Style

The target visual language is a light Material-inspired system:

- White elevated cards on a pale gray-lavender background.
- Purple primary color for labels, active states, selection, and filled controls.
- Rounded pill buttons and soft component cards.
- Subtle shadows for hierarchy instead of heavy borders.
- Uppercase section labels with wider tracking.
- Tinted input fields with a stronger bottom rule.

## Current App Changes

- Added shared design tokens in `config/design-tokens.json`, generated into `Chiselo/MaterialTheme.swift` for SwiftUI and `Chiselo/Resources/Editor/design-tokens.css` for the Web editor.
- Replaced the plain macOS toolbar with a branded Material toolbar using pill buttons and a mode capsule.
- Restyled the left navigator with Material panel headers, elevated page cards, and object labels.
- Restyled the Inspector with a custom `MaterialGroupBoxStyle` so every control group becomes a white elevated component card.
- Restyled number and text inputs with tinted backgrounds and bottom rules.
- Restyled command buttons as compact rounded Material controls.
- Updated the Web editor shell in `editor.css` to use the same purple accent, pale background, rounded stage, softer grid, and Material selection boxes.

## Product Fit

This direction is appropriate for Chiselo because the app is a finishing surface for existing HTML pages and visual documents, not a blank-project authoring environment. The UI should emphasize:

- Selecting visible page objects.
- Adjusting layout precisely.
- Editing visual styles directly on the HTML asset.
- Handling cards, tables, images, sections, and repeated page components.

## Remaining UI Opportunities

- Add a compact top tab/segmented control for `Layout`, `Style`, `Structure`, and `Media`.
- Add a breadcrumb component for selected object ancestry.
- Add swatch pickers for the Material palette instead of free-form color strings only.
- Add a zoom slider and page minimap using the same Material player/progress visual language.
- Add better visual affordances for group selection and nested object targets.
