#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/outputs}"
DEFAULT_VERSION="$(node -p "require(process.argv[1]).version" "$ROOT_DIR/config/release.json")"
DEFAULT_BUILD_NUMBER="$(node -p "require(process.argv[1]).buildNumber" "$ROOT_DIR/config/release.json")"
BUCKET="${CHISELO_R2_BUCKET:-vellumloop-downloads}"
PREFIX="${CHISELO_R2_PREFIX:-chiselo}"
PUBLIC_BASE_URL="${CHISELO_DOWNLOAD_BASE_URL:-https://downloads.vellumloop.com}"
VERSION="${CHISELO_VERSION:-$DEFAULT_VERSION}"
BUNDLE_VERSION="${CHISELO_BUILD_NUMBER:-$DEFAULT_BUILD_NUMBER}"
ARCH="${CHISELO_PUBLIC_ARCH:-$(uname -m)}"
APP_BUNDLE="${CHISELO_APP_BUNDLE:-$OUTPUT_DIR/Chiselo.app}"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
PREPARE_ONLY=0

if [[ "${1:-}" == "--prepare-only" ]]; then
  PREPARE_ONLY=1
  shift
fi
if (( $# > 0 )); then
  echo "Usage: scripts/publish-r2-release.sh [--prepare-only]" >&2
  exit 2
fi

case "$ARCH" in
  arm64) PUBLIC_ARCH="arm64" ;;
  x86_64) PUBLIC_ARCH="x86_64" ;;
  *) PUBLIC_ARCH="$ARCH" ;;
esac

DMG_PATH="$OUTPUT_DIR/Chiselo-${VERSION}.dmg"
APPCAST_PATH="$OUTPUT_DIR/Chiselo-${VERSION}-macOS-${PUBLIC_ARCH}-appcast.xml"
LATEST_APPCAST_PATH="$OUTPUT_DIR/latest/appcast-$PUBLIC_ARCH.xml"
SHA_PATH="$OUTPUT_DIR/Chiselo-${VERSION}.dmg.sha256"
MANIFEST_PATH="$OUTPUT_DIR/chiselo-release.json"

if [[ -n "${WRANGLER_BIN:-}" ]]; then
  WRANGLER=("$WRANGLER_BIN")
elif command -v wrangler >/dev/null 2>&1; then
  WRANGLER=(wrangler)
else
  WRANGLER=(npx --yes wrangler)
fi

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
}

upload_object() {
  local key="$1"
  local file="$2"
  local content_type="$3"
  local content_disposition="${4:-}"
  local cache_control="${5:-public, max-age=300}"

  local args=(
    r2 object put "$BUCKET/$key"
    --file "$file"
    --content-type "$content_type"
    --cache-control "$cache_control"
    --remote
  )
  if [[ -n "$content_disposition" ]]; then
    args+=(--content-disposition "$content_disposition")
  fi
  "${WRANGLER[@]}" "${args[@]}"
}

require_file "$DMG_PATH"
require_file "$APPCAST_PATH"
require_file "$LATEST_APPCAST_PATH"
require_file "$INFO_PLIST"

asset_name="Chiselo-$VERSION.dmg"
latest_name="Chiselo-latest-macOS-$PUBLIC_ARCH.dmg"
appcast_name="Chiselo-$VERSION-macOS-$PUBLIC_ARCH-appcast.xml"
latest_appcast_name="appcast-$PUBLIC_ARCH.xml"
generic_latest_appcast_name="appcast.xml"
build_fingerprint="$(plutil -extract ChiseloBuildFingerprint raw -o - "$INFO_PLIST")"
download_url="${CHISELO_DOWNLOAD_URL:-${PUBLIC_BASE_URL%/}/$PREFIX/$asset_name?build=$build_fingerprint}"
latest_download_url="${CHISELO_LATEST_DOWNLOAD_URL:-${PUBLIC_BASE_URL%/}/$PREFIX/latest/$latest_name?build=$build_fingerprint}"
size_bytes="$(stat -f '%z' "$DMG_PATH")"
checksum="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

printf '%s  %s\n' "$checksum" "$asset_name" > "$SHA_PATH"

cat > "$MANIFEST_PATH" <<MANIFEST
{
  "product": "chiselo",
  "version": "$VERSION",
  "bundle_version": "$BUNDLE_VERSION",
  "arch": "$PUBLIC_ARCH",
  "filename": "$asset_name",
  "latest_filename": "$latest_name",
  "appcast_filename": "$appcast_name",
  "size_bytes": $size_bytes,
  "sha256": "$checksum",
  "download_url": "$download_url",
  "latest_download_url": "$latest_download_url",
  "appcast_url": "${PUBLIC_BASE_URL%/}/$PREFIX/latest/$latest_appcast_name"
}
MANIFEST

echo "R2 bucket: $BUCKET"
echo "R2 prefix: $PREFIX"
echo "Version: $VERSION ($BUNDLE_VERSION)"
echo "DMG size: $size_bytes"
echo "SHA-256: $checksum"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "Prepared release metadata without uploading."
  echo "Checksum: $SHA_PATH"
  echo "Manifest: $MANIFEST_PATH"
  exit 0
fi

upload_object "$PREFIX/$asset_name" \
  "$DMG_PATH" \
  "application/x-apple-diskimage" \
  "attachment; filename=\"$asset_name\"" \
  "public, max-age=31536000, immutable"

upload_object "$PREFIX/latest/$latest_name" \
  "$DMG_PATH" \
  "application/x-apple-diskimage" \
  "attachment; filename=\"$latest_name\"" \
  "public, max-age=300"

upload_object "$PREFIX/$asset_name.sha256" \
  "$SHA_PATH" \
  "text/plain" \
  "attachment; filename=\"$asset_name.sha256\"" \
  "public, max-age=31536000, immutable"

upload_object "$PREFIX/latest/release.json" \
  "$MANIFEST_PATH" \
  "application/json" \
  "" \
  "public, max-age=300"

upload_object "$PREFIX/$appcast_name" \
  "$APPCAST_PATH" \
  "application/xml" \
  "" \
  "public, max-age=31536000, immutable"

upload_object "$PREFIX/latest/$latest_appcast_name" \
  "$LATEST_APPCAST_PATH" \
  "application/xml" \
  "" \
  "public, max-age=300"

upload_object "$PREFIX/latest/$generic_latest_appcast_name" \
  "$LATEST_APPCAST_PATH" \
  "application/xml" \
  "" \
  "public, max-age=300"

"$ROOT_DIR/scripts/verify-online-update.sh"
echo "Uploaded Chiselo $VERSION to R2."
