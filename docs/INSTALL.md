# Install

## DMG Install

1. Download `Chiselo-0.1.2.dmg` from GitHub Releases.
2. Open the DMG.
3. Drag `Chiselo.app` to `Applications`.
4. Launch Chiselo from `Applications`.

Current preview builds are ad-hoc signed and not notarized. If macOS blocks the first launch, try these in order:

1. Move `Chiselo.app` to `Applications`, then Finder right-click -> `Open`.
2. Check `System Settings -> Privacy & Security` for an `Open Anyway` button.
3. If macOS says the app is damaged or should be moved to Trash, and you trust the download, run:

```bash
xattr -dr com.apple.quarantine /Applications/Chiselo.app
```

The DMG also includes `首次打开帮助.txt` with these steps.

## Build Locally

```bash
swift build
swift run Chiselo
```

## Package Locally

```bash
scripts/package-dmg.sh
```

Outputs:

```text
outputs/Chiselo.app
outputs/Chiselo-0.1.2.dmg
```

Custom output directory:

```bash
OUTPUT_DIR=/path/to/output scripts/package-dmg.sh
```
