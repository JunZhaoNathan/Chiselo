---
version: alpha
name: Chiselo-design-system
description: "Chiselo is a precise HTML and slide delivery editor. The interface should feel like a quiet Mac-native creative workstation: light gray-blue canvas chrome, translucent inspection panels, exact object controls, and a restrained system-blue action language. The product is not a marketing site and not a decorative dashboard. It is a work surface for selecting, dragging, editing, validating, and exporting real documents with confidence."
---

# Chiselo Design System

This file is the visual and interaction contract for Chiselo across the current macOS app and any future Electron or web shell. Prefer these rules over ad-hoc styling when changing toolbar controls, canvas overlays, inspectors, export panels, diagnostics, or generated UI.

## 1. Product Feel

Chiselo should feel:

- Precise, calm, and document-first.
- Native enough to belong on macOS, but structured enough to port to Windows.
- Dense where professionals need repeated controls; airy only around the central canvas.
- Trustworthy during risky operations like save, export, source editing, and visual change review.
- AI-assisted without looking like a chatbot product.

Chiselo should not feel:

- Like a SaaS landing page.
- Like a dark IDE by default.
- Like a colorful presentation template.
- Like a generic admin dashboard.
- Like an experimental toy with decorative gradients or oversized cards.

## 2. Color Tokens

Current source of truth:

- `config/design-tokens.json`
- `Chiselo/Resources/Editor/design-tokens.css`
- `Chiselo/MaterialTheme.swift`

Use these semantic roles:

```yaml
colors:
  canvas-background: "#ECF0F6"
  surface-glass: "rgba(255,255,255,0.70)"
  surface-strong: "rgba(255,255,255,0.92)"
  surface-tint: "rgba(246,249,253,0.72)"
  surface-floating: "rgba(255,255,255,0.86)"
  surface-chrome: "rgba(248,251,255,0.64)"
  action-primary: "#0A84FF"
  action-primary-dark: "#073F78"
  danger: "#C0262D"
  danger-soft: "#FFF7F7"
  success: "#0F853F"
  success-soft: "#EAF7EF"
  warning: "#C7780F"
  warning-soft: "#FFF6D8"
  ink: "#131518"
  muted: "#5D636E"
  muted-overlay: "rgba(60,60,67,0.72)"
  hairline: "rgba(255,255,255,0.58)"
  separator: "rgba(0,0,0,0.075)"
  shadow: "rgba(0,0,0,0.16)"
  glow: "rgba(0,122,199,0.13)"
  guide: "#0A84FF"
```

Rules:

- Primary blue is for current selection, guides, primary actions, focus states, and active object controls.
- Danger red is reserved for destructive actions, broken resources, locked/blocked states, and export-blocking issues.
- Warning amber is reserved for review-needed states: visual changes, responsive changes, PPTX risks, source writeback review.
- Success green is reserved for completed validation and low-risk export states.
- Panels may be translucent, but text and controls must remain legible against the canvas.
- Avoid dominant purple, beige, or one-note blue palettes. Blue is an operational signal, not the whole visual identity.

## 3. Typography

Default family:

```yaml
fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', Arial, sans-serif"
monoFamily: "'SF Mono', 'JetBrains Mono', 'Menlo', Consolas, monospace"
```

Type roles:

```yaml
typography:
  app-title:
    size: 22
    weight: 800
    design: rounded
  panel-title:
    size: 22
    weight: 800
    design: rounded
  section-label:
    size: 11
    weight: 800
    tracking: 1.8
    transform: uppercase
  button:
    size: 13
    weight: 700
  compact-button:
    size: 12
    weight: 700
  inspector-label:
    size: 11
    weight: 800
  inspector-value:
    size: 12
    weight: 600
  caption:
    size: 10
    weight: 700
  canvas-badge:
    size: 11
    weight: 760
  source-code:
    size: 12
    weight: 500
    family: monoFamily
```

Rules:

- Do not use hero-scale type inside the app shell.
- Use rounded heavy titles sparingly for product identity and panel headers.
- Inspector and diagnostic text should be compact, scannable, and never marketing-like.
- Letter spacing should usually be `0`; tracking is allowed only for small section labels and mode badges.
- Source code, CSS selectors, HTML paths, and diagnostics identifiers use monospace.

## 4. Shape, Radius, And Elevation

```yaml
rounded:
  small: 8
  medium: 12
  panel: 16
  stage: 14
  pill: 9999

spacing:
  xxs: 4
  xs: 8
  sm: 12
  panel-padding: 14
  md: 16
  lg: 24
  viewport-padding: 34
  canvas-grid-size: 24

shadow:
  canvas: "0 22px 60px rgba(0,0,0,0.16)"
  floating-control: "0 8px 22px rgba(0,0,0,0.12)"
  menu: "0 16px 34px rgba(0,0,0,0.18)"
  sidebar: "0 4px 12px rgba(0,0,0,0.07)"
```

Rules:

- Canvas stage radius is `14px`; repeated cards and panels should stay at `8-16px`.
- Tool buttons use `8px` radius unless they are small icon-only circular controls.
- Pills are for badges, paths, filters, and compact status metadata.
- Avoid nested cards. Use one panel surface, then rows or bands inside it.
- Elevation must imply utility: canvas, floating quick actions, menus, modals. Do not add shadows for decoration.

## 5. Layout Principles

App shell:

- Top toolbar is command-first: file actions, conversion, undo/redo, export, backdrop, mode status.
- Left side is navigation/structure; center is the canvas; right side is properties and source controls.
- Keep the canvas as the main visual anchor. Panels support the canvas; they do not compete with it.
- Preserve the current proportions: left panel about `170-380px`, canvas minimum about `560px`, inspector about `250-480px`.

Canvas:

- The stage is a white document surface over a light gray-blue workstation.
- Background modes may be plain, grid, or dots. Grid/dots must remain subtle.
- Page boundaries, guides, hover boxes, and selection boxes must scale with zoom and never obscure the object being manipulated.
- Text must never overlap controls in a way that blocks editing.

Inspector:

- Group controls by task: object identity, layout, style, arrange, HTML/source.
- Prefer compact grouped rows over large cards.
- Put dangerous actions near explanatory context, not next to routine adjustments.

Export and diagnostics:

- Export panels are decision surfaces, not marketing pages.
- Present HTML, PDF, and PPTX readiness as comparable score cards.
- Every warning or error should offer a path to locate, fix, export safer, or intentionally proceed.

## 6. Component Rules

### Toolbar Button

```yaml
toolbar-button:
  height: 32-36
  paddingX: 14
  paddingY: 9
  radius: 8
  background: surface-glass
  text: action-primary-dark
  icon: SF Symbols on macOS; equivalent lucide/icon library on Electron
```

States:

- Hover: stronger white surface and subtle shadow.
- Pressed: scale to `0.98`, reduce shadow.
- Disabled: opacity around `0.56`, muted text, no strong shadow.
- Filled primary: `#0A84FF` background and white text.

### Icon Button

- Use icon-only buttons for undo, redo, refresh, close, locate, expand/collapse, and compact tool controls.
- Always provide tooltip/help text.
- Use fixed dimensions so state changes do not shift layout.

### Sidebar Panel

```yaml
sidebar-panel:
  background: thin material or surface-strong equivalent
  radius: 16
  border: hairline
  shadow: sidebar
  padding: 14
```

Rules:

- Sidebars must feel stable and quiet.
- No decorative hero blocks.
- Empty states may use one icon, one title, one short helper sentence.

### Selection Box

```yaml
selection-box:
  border: 2px solid action-primary
  radius: 8
  lockedBorder: danger
  groupBorder: dashed action-primary
  groupFill: rgba(10,132,255,0.045)
```

Rules:

- Selected objects must remain visibly selected at every zoom level.
- Resize handles are white circles with primary blue border and shadow.
- Locked states turn red and must show why editing is blocked.
- Group selections use dashed boundaries, not a separate decorative container.

### Quick Action Bar

```yaml
quick-action-bar:
  collapsedWidth: 28
  minHeight: 26
  background: rgba(255,255,255,0.56)
  openBackground: rgba(255,255,255,0.88)
  radiusCollapsed: pill
  radiusOpen: 12
```

Rules:

- Collapsed quick actions should be small and quiet until hover/focus.
- Open menus may show object path, parent/sibling/child navigation, duplicate, delete, and edit actions.
- Destructive quick actions use danger red text and a light red hover background.
- Do not let quick actions trap pointer gestures after pointerup, pointercancel, mouseup, iframe boundary crossing, or window blur.

### Diagnostics Card

- Use success, warning, and danger color lanes consistently.
- Warnings should describe risk and next action.
- Errors should identify the blocking condition and the affected object when possible.
- Visual change review must include filter, map/list, target navigation, and revert affordance when available.

### Source Editing

- HTML snippets use a monospace editor surface.
- Validation badges must distinguish safe, risky, and rejected changes.
- Source writeback badges must say whether changes target inline style, stylesheet rule, external stylesheet review, or clean source.
- Source edits must preserve clean export: no Chiselo runtime data, no debug artifacts, no accidental test state.

## 7. Interaction Rules

Pointer and gesture behavior:

- A gesture starts once and ends reliably.
- Listen for pointerup, pointercancel, mouseup, cross-document release, and blur.
- Release pointer capture and clear guides at the end of every gesture.
- Moving the pointer after release must never keep dragging or resizing.
- Drag, resize, zoom, and selection must be tested inside the HTML iframe and from the parent shell.

Keyboard behavior:

- Undo/redo must reflect visible history labels.
- Escape exits transient editing modes safely.
- Command/Ctrl+Enter commits text/source edits when supported.
- Keyboard shortcuts must not leave contenteditable, typography locks, selection overlays, or guide layers behind.

Feedback:

- Hover shows possibility; selection shows commitment; diagnostics show consequence.
- Every destructive action should either be undoable, reversible through history, or clearly confirmed.
- Save and overwrite flows must preserve safe file history.

## 8. Responsive And Cross-Platform Behavior

macOS:

- Prefer SF Symbols, SwiftUI material, native file panels, native menu behavior, and system font rendering.

Electron / Windows:

- Use the same design tokens, spacing, component geometry, and interaction rules.
- Replace SF Symbols with a coherent icon set such as lucide, matching metaphors one-for-one.
- Do not depend on macOS material blur for legibility; provide solid fallback surfaces.
- Re-test font metrics, canvas screenshots, PDF export, PPTX export, drag release, and file history under Chromium.

Breakpoints:

- Desktop-first. Chiselo is not a phone-first editor.
- Below `1100px`, side panels may collapse or become tabs.
- Below `900px`, keep core document viewing and export review possible, but full precision editing may require a wider window.

## 9. Do And Do Not

Do:

- Keep controls compact and predictable.
- Prefer existing tokens and components before adding new styles.
- Use icons for familiar tool actions.
- Make button labels direct: Open, Save, Export, Refresh, Revert, Locate.
- Keep diagnostics tied to affected objects.
- Preserve a clean, document-centered canvas.
- Verify changes with automated interaction tests and screenshots when layout is involved.

Do not:

- Add marketing hero sections inside the app.
- Add decorative gradient blobs, abstract background art, or oversized promotional cards.
- Invent a second accent palette for one feature.
- Hide critical export risk in secondary text only.
- Use cards inside cards.
- Let hover, focus, pressed, disabled, loading, or selected states resize controls.
- Use visible explanatory text to describe obvious UI mechanics.

## 10. Implementation Guidance For Agents

When editing Chiselo UI:

1. Read `DESIGN.md`, `config/design-tokens.json`, and the nearest existing component before changing styles.
2. Reuse `MaterialTheme` and generated CSS variables when possible.
3. Keep Mac SwiftUI and Web editor token names aligned.
4. Add a token before hard-coding a repeated color, radius, shadow, or spacing value.
5. For new tool actions, provide icon, label, tooltip/help, disabled state, hover/pressed state, and test coverage.
6. For new canvas overlays, test at multiple zoom levels and after cross-frame pointer release.
7. For export or source features, test clean export and safe history behavior.
8. For Electron migration, keep renderer UI behavior equivalent to the macOS app before exploring new platform-specific affordances.

Useful reference families:

- Linear for precision, restraint, and dense product craft.
- Cursor for AI editing workflow language and code/source surfaces.
- Figma and Webflow for canvas object selection, quick actions, and creative-tool ergonomics.

These are inspirations only. Chiselo must remain its own product.

## 11. Test Checklist

Before shipping visual or interaction changes:

- Build succeeds.
- Selection, hover, drag, resize, zoom, and iframe boundary release pass.
- Quick action buttons open, locate, select parent/sibling/child, duplicate, and delete as expected.
- Toolbar buttons retain stable sizing across enabled/disabled/pressed states.
- Inspector tabs and source editing controls remain readable at minimum panel width.
- Export preflight shows HTML/PDF/PPTX states and can locate affected objects.
- Undo/redo labels match the next available history action.
- Clean export contains no Chiselo runtime artifacts.
- Screenshots show no overlapping text, clipped buttons, or drifting overlay geometry.
