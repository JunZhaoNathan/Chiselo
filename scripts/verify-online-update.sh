#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/outputs}"
DEFAULT_VERSION="$(node -p "require(process.argv[1]).version" "$ROOT_DIR/config/release.json")"
DEFAULT_BUILD_NUMBER="$(node -p "require(process.argv[1]).buildNumber" "$ROOT_DIR/config/release.json")"
VERSION="${CHISELO_VERSION:-$DEFAULT_VERSION}"
BUNDLE_VERSION="${CHISELO_BUILD_NUMBER:-$DEFAULT_BUILD_NUMBER}"
ARCH="${CHISELO_PUBLIC_ARCH:-$(uname -m)}"
BUCKET_PREFIX="${CHISELO_R2_PREFIX:-chiselo}"
DOWNLOAD_BASE_URL="${CHISELO_DOWNLOAD_BASE_URL:-https://downloads.vellumloop.com}"

case "$ARCH" in
  arm64) PUBLIC_ARCH="arm64" ;;
  x86_64) PUBLIC_ARCH="x86_64" ;;
  *) PUBLIC_ARCH="$ARCH" ;;
esac

DMG_PATH="$OUTPUT_DIR/Chiselo-${VERSION}.dmg"
APPCAST_PATH="$OUTPUT_DIR/Chiselo-${VERSION}-macOS-${PUBLIC_ARCH}-appcast.xml"
LATEST_APPCAST_PATH="$OUTPUT_DIR/latest/appcast-$PUBLIC_ARCH.xml"
APP_BUNDLE="${CHISELO_APP_BUNDLE:-$OUTPUT_DIR/Chiselo.app}"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
FEED_URL="${CHISELO_SPARKLE_FEED_URL:-${DOWNLOAD_BASE_URL%/}/$BUCKET_PREFIX/latest/appcast-$PUBLIC_ARCH.xml}"
DMG_URL="${CHISELO_DOWNLOAD_URL:-}"
LATEST_DMG_URL="${CHISELO_LATEST_DOWNLOAD_URL:-}"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
}

content_length() {
  local url="$1"
  curl -fsSIL --connect-timeout 20 --max-time 60 "$url" \
    | awk 'BEGIN { IGNORECASE=1 } /^content-length:/ { value=$2 } END { gsub("\r", "", value); print value }'
}

require_file "$DMG_PATH"
require_file "$APPCAST_PATH"
require_file "$LATEST_APPCAST_PATH"
require_file "$INFO_PLIST"

if ! cmp -s "$APPCAST_PATH" "$LATEST_APPCAST_PATH"; then
  echo "Versioned and latest local appcasts differ." >&2
  exit 1
fi

packaged_version="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
packaged_build="$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")"
packaged_feed_url="$(plutil -extract SUFeedURL raw -o - "$INFO_PLIST")"
sparkle_public_key="$(plutil -extract SUPublicEDKey raw -o - "$INFO_PLIST")"
build_fingerprint="$(plutil -extract ChiseloBuildFingerprint raw -o - "$INFO_PLIST")"
if [[ -z "$DMG_URL" ]]; then
  DMG_URL="${DOWNLOAD_BASE_URL%/}/$BUCKET_PREFIX/Chiselo-${VERSION}.dmg?build=$build_fingerprint"
fi
if [[ -z "$LATEST_DMG_URL" ]]; then
  LATEST_DMG_URL="${DOWNLOAD_BASE_URL%/}/$BUCKET_PREFIX/latest/Chiselo-latest-macOS-$PUBLIC_ARCH.dmg?build=$build_fingerprint"
fi

if [[ "$packaged_version" != "$VERSION" || "$packaged_build" != "$BUNDLE_VERSION" ]]; then
  echo "Packaged app version mismatch: app=$packaged_version ($packaged_build), expected=$VERSION ($BUNDLE_VERSION)" >&2
  exit 1
fi

if [[ "$packaged_feed_url" != "$FEED_URL" ]]; then
  echo "Packaged SUFeedURL mismatch: app=$packaged_feed_url expected=$FEED_URL" >&2
  exit 1
fi

swift "$ROOT_DIR/scripts/chiselo-sparkle-tool.swift" verify-appcast \
  --appcast "$APPCAST_PATH" \
  --archive "$DMG_PATH" \
  --public-key "$sparkle_public_key" \
  --short-version "$VERSION" \
  --bundle-version "$BUNDLE_VERSION" \
  --download-url "$DMG_URL"

expected_size="$(stat -f '%z' "$DMG_PATH")"
temporary_directory="$(mktemp -d /tmp/chiselo-update-verification.XXXXXX)"
trap 'rm -rf "$temporary_directory"' EXIT
online_feed_path="$temporary_directory/appcast.xml"
online_versioned_dmg="$temporary_directory/versioned.dmg"
online_latest_dmg="$temporary_directory/latest.dmg"

curl -fsSL --connect-timeout 20 --max-time 60 "$FEED_URL" -o "$online_feed_path"
feed="$(<"$online_feed_path")"

if [[ "$feed" != *"<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>"* ]]; then
  echo "Online appcast does not advertise version $VERSION: $FEED_URL" >&2
  exit 1
fi

if [[ "$feed" != *"<sparkle:version>$BUNDLE_VERSION</sparkle:version>"* ]]; then
  echo "Online appcast does not advertise bundle version $BUNDLE_VERSION: $FEED_URL" >&2
  exit 1
fi

if [[ "$feed" != *"url=\"$DMG_URL\""* ]]; then
  echo "Online appcast does not point at $DMG_URL" >&2
  exit 1
fi

if [[ "$feed" != *"length=\"$expected_size\""* ]]; then
  echo "Online appcast length does not match local DMG size $expected_size" >&2
  exit 1
fi

if ! cmp -s "$APPCAST_PATH" "$online_feed_path"; then
  echo "Online appcast bytes do not match the locally signed appcast." >&2
  exit 1
fi

versioned_size="$(content_length "$DMG_URL")"
latest_size="$(content_length "$LATEST_DMG_URL")"

if [[ "$versioned_size" != "$expected_size" ]]; then
  echo "Versioned DMG size mismatch: online=$versioned_size local=$expected_size" >&2
  exit 1
fi

if [[ "$latest_size" != "$expected_size" ]]; then
  echo "Latest DMG size mismatch: online=$latest_size local=$expected_size" >&2
  exit 1
fi


curl -fsSL --connect-timeout 20 --max-time 300 "$DMG_URL" -o "$online_versioned_dmg"
curl -fsSL --connect-timeout 20 --max-time 300 "$LATEST_DMG_URL" -o "$online_latest_dmg"
local_sha256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
versioned_sha256="$(shasum -a 256 "$online_versioned_dmg" | awk '{print $1}')"
latest_sha256="$(shasum -a 256 "$online_latest_dmg" | awk '{print $1}')"

if [[ "$versioned_sha256" != "$local_sha256" ]]; then
  echo "Versioned DMG SHA-256 mismatch: online=$versioned_sha256 local=$local_sha256" >&2
  exit 1
fi

if [[ "$latest_sha256" != "$local_sha256" ]]; then
  echo "Latest DMG SHA-256 mismatch: online=$latest_sha256 local=$local_sha256" >&2
  exit 1
fi

echo "Online update OK"
echo "Feed: $FEED_URL"
echo "DMG: $DMG_URL"
echo "Latest DMG: $LATEST_DMG_URL"
echo "SHA-256: $local_sha256"
