# Release Guide

## Before Release

Run:

```bash
scripts/release-preflight.sh
```

## Build DMG

```bash
scripts/package-dmg.sh
```

Confirm:

```bash
codesign --verify --deep --strict --verbose=2 outputs/Chiselo.app
hdiutil verify outputs/Chiselo-0.1.0.dmg
```

## GitHub Release

1. Create a tag such as `v0.1.0`.
2. Create a GitHub release from that tag.
3. Upload `outputs/Chiselo-0.1.0.dmg`.
4. Include release notes from `docs/RELEASE_NOTES_0.1.0_PREVIEW.md` for the first preview.

Do not commit `.app` or `.dmg` binaries to the repository. Upload them as release assets.

For first-time publishing, use [GITHUB_PUBLISHING.md](GITHUB_PUBLISHING.md).

For routine update pushes after the repository exists, use [GITHUB_UPDATE_WORKFLOW.md](GITHUB_UPDATE_WORKFLOW.md).
