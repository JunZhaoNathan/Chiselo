# Chiselo 0.1.15 Preview

Chiselo 0.1.15 completes the current light-Dreamweaver optimization pass for safely refining existing HTML without creating a site project.

## Highlights

- Bumped the app version to `0.1.15` and the Sparkle build number to `15`.
- Protects modified tabs and application quit with Save, Cancel, and Don't Save decisions based on the latest WebKit document state.
- Saves HTML and changed linked local CSS as one rollback-capable transaction.
- Preserves untouched HTML byte for byte until the first real edit.
- Opens HTML in static safety mode by default, with dynamic scripts and forms available only through an explicit trusted-document choice.
- Adds exact desktop (`1440px`), tablet (`768px`), and phone (`390px`) previews without changing HTML or undo history.
- Keeps ordinary mode focused on direct visual editing while retaining professional source, runtime, review, and export controls in advanced mode.
- Runs the complete release preflight in CI, including visual QA and editable PDF/PPTX export checks.

## Update Safety

- Release version and build metadata now come from `config/release.json` so packaging, publishing, and verification cannot silently drift apart.
- Sparkle verification checks the packaged app version, build number, feed URL, Ed25519 archive signature, exact online appcast bytes, and SHA-256 hashes of both versioned and latest DMGs.
- The online update is not considered published until `scripts/verify-online-update.sh` passes after upload.

## Package Notes

- Build the release with `CHISELO_NOTARIZE=1 scripts/package-dmg.sh` so the Developer ID signed package is notarized and stapled before its appcast is generated.
- Run `scripts/publish-r2-release.sh --prepare-only` to create the checksum and release manifest while keeping the build local.
- Publish with `scripts/publish-r2-release.sh`; the script uploads the versioned and latest assets and then runs online verification.
- The generated release files are `outputs/Chiselo-0.1.15.dmg`, `outputs/Chiselo-0.1.15-macOS-arm64-appcast.xml`, and `outputs/latest/appcast-arm64.xml`.

## Product Boundary

Chiselo now covers the core workflow of a light Dreamweaver for static and conventional HTML. It deliberately does not replace full site management, FTP, backend development, framework tooling, databases, or a general-purpose code IDE.
