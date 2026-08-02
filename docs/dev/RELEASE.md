# Release Guide

## Before Release

Run:

```bash
scripts/release-preflight.sh
```

## Build DMG

```bash
CHISELO_NOTARIZE=1 scripts/package-dmg.sh
```

Confirm:

```bash
codesign --verify --deep --strict --verbose=2 outputs/Chiselo.app
hdiutil verify outputs/Chiselo-0.1.20.dmg
xcrun stapler validate outputs/Chiselo-0.1.20.dmg
spctl --assess --type open --context context:primary-signature --verbose=4 outputs/Chiselo-0.1.20.dmg
plutil -p outputs/Chiselo.app/Contents/Info.plist | grep -E 'SUPublicEDKey|SUFeedURL|CFBundleShortVersionString|CFBundleVersion'
```

## Publish Update Feed

Sparkle updates are not live until the DMG and appcast are uploaded to the download bucket.

To create the checksum and release manifest without uploading:

```bash
scripts/publish-r2-release.sh --prepare-only
```

```bash
scripts/publish-r2-release.sh
scripts/verify-online-update.sh
```

The online verification must pass before telling users to use `检查更新…`.

## GitHub Release

1. Create a release tag such as `v0.1.20`.
2. Create a GitHub release from that tag.
3. Upload `outputs/Chiselo-0.1.20.dmg`.
4. Include release notes from `docs/releases/RELEASE_NOTES_0.1.20_PREVIEW.md` for the current preview.
5. Upload the generated Sparkle appcast, such as `outputs/latest/appcast-arm64.xml`, to the feed URL written into `SUFeedURL`, or run `scripts/publish-r2-release.sh`.
6. Run `scripts/verify-online-update.sh`.
7. Do not mark downloadable public builds as `Pre-release`. GitHub's `/releases/latest` endpoint ignores prereleases, so website download buttons should point at a normal latest release.

Do not commit `.app` or `.dmg` binaries to the repository. Upload them as release assets.

For first-time publishing, use [GITHUB_PUBLISHING.md](GITHUB_PUBLISHING.md).

For routine update pushes after the repository exists, use [GITHUB_UPDATE_WORKFLOW.md](GITHUB_UPDATE_WORKFLOW.md).
