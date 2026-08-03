# Contributing

Thanks for helping Chiselo improve.

Chiselo is open-source software under [Apache-2.0](../LICENSE). By submitting
a contribution, you license it under Apache-2.0. The Chiselo name, icon,
tagline, and Vellumloop branding remain subject to the
[Trademark Policy](../TRADEMARKS.md).

## Ground Rules

- Keep the product goal clear: Chiselo is an HTML finishing and delivery tool, focused on precise visual refinement, delivery checks, and HTML/PDF/PPTX export.
- Prefer small, testable changes.
- Do not add license-incompatible dependencies or proprietary code.
- Do not paste proprietary code or private documents into issues or pull requests.
- Include before/after screenshots for visual editing changes when possible.

## Development Setup

```bash
swift build
swift run Chiselo
```

Useful checks:

```bash
node --check Chiselo/Resources/Editor/editor.js
swift scripts/import-smoke-test.swift
swift scripts/import-adapter-test.swift
swift scripts/precision-adjustment-test.swift
```

## Pull Requests

Good pull requests include:

- a short explanation of the problem;
- the implementation approach;
- commands that were run;
- screenshots or exported artifacts for UI/export changes;
- notes about limitations or remaining risks.

## Project Voice

The repository is intentionally honest that Chiselo started as a vibe-coded project by a non-programmer using AI assistance. Improvements are welcome, but please keep feedback practical and kind.
