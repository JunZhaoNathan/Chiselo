# Contributing

Thanks for helping Chiselo improve.

Chiselo is publicly source-available under [CC BY-NC 4.0](../LICENSE), not an
OSI-approved open-source license. By submitting a contribution, you license it
under CC BY-NC 4.0. The Chiselo name, icon, tagline, and Vellumloop branding
remain subject to the
[Trademark Policy](../TRADEMARKS.md).

## Ground Rules

- Keep the product goal clear: Chiselo is an HTML finishing and delivery tool, focused on precise visual refinement, delivery checks, and HTML/PDF/PPTX export.
- Prefer small, testable changes.
- Do not add license-incompatible dependencies, proprietary code, or material
  that you do not have the right to contribute.
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
