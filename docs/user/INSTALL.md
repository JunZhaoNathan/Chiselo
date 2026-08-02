# Install

## DMG Install

1. Download the latest `Chiselo-0.1.x.dmg` from GitHub Releases.
2. Open the DMG.
3. Drag `Chiselo.app` to `Applications`.
4. Launch Chiselo from `Applications`.

Current preview builds are Developer ID signed when the signing identity is available. Release packaging can be notarized and stapled with `CHISELO_NOTARIZE=1 scripts/package-dmg.sh`. If macOS blocks the first launch, try these in order:

1. Move `Chiselo.app` to `Applications`, then Finder right-click -> `Open`.
2. Check `System Settings -> Privacy & Security` for an `Open Anyway` button.
3. If macOS says the app is damaged or should be moved to Trash, and you trust the download, run:

```bash
xattr -dr com.apple.quarantine /Applications/Chiselo.app
```

The DMG includes `README.txt` and `更新说明.txt` with the current install, signing, and release notes.

## Build Locally

```bash
swift build
swift run Chiselo
```

## Package Locally

```bash
scripts/package-dmg.sh
```

For a notarized release package:

```bash
CHISELO_NOTARIZE=1 scripts/package-dmg.sh
```

Outputs:

```text
outputs/Chiselo.app
outputs/Chiselo-0.1.20.dmg
outputs/Chiselo-0.1.20-macOS-arm64-appcast.xml
outputs/latest/appcast-arm64.xml
```

Publish the update feed after packaging:

```bash
scripts/publish-r2-release.sh
scripts/verify-online-update.sh
```

Custom output directory:

```bash
OUTPUT_DIR=/path/to/output scripts/package-dmg.sh
```
