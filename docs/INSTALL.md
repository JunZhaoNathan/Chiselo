# Install

## DMG Install

1. Download `Chiselo-0.1.1.dmg` from GitHub Releases.
2. Open the DMG.
3. Drag `Chiselo.app` to `Applications`.
4. Launch Chiselo from `Applications`.

Current preview builds are ad-hoc signed and not notarized. If macOS blocks the first launch, use Finder right-click -> Open.

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
outputs/Chiselo-0.1.1.dmg
```

Custom output directory:

```bash
OUTPUT_DIR=/path/to/output scripts/package-dmg.sh
```
