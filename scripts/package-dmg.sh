#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/outputs}"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/outputs"
APP_NAME="Chiselo"
BUNDLE_ID="com.fangle.chiselo"
DEFAULT_VERSION="$(node -p "require(process.argv[1]).version" "$ROOT_DIR/config/release.json")"
DEFAULT_BUILD_NUMBER="$(node -p "require(process.argv[1]).buildNumber" "$ROOT_DIR/config/release.json")"
VERSION="${CHISELO_VERSION:-$DEFAULT_VERSION}"
BUNDLE_VERSION="${CHISELO_BUILD_NUMBER:-$DEFAULT_BUILD_NUMBER}"
BUILD_CONFIG="release"
BUILD_DIR=""
APP_BUNDLE="$ROOT_DIR/.build/package/$APP_NAME.app"
ADHOC_ENTITLEMENTS="$ROOT_DIR/.build/package/$APP_NAME-adhoc-entitlements.plist"
DMG_STAGING="$ROOT_DIR/.build/dmg-staging"
OUTPUT_APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
DEFAULT_OUTPUT_APP_BUNDLE="$DEFAULT_OUTPUT_DIR/$APP_NAME.app"
DMG_PATH="$OUTPUT_DIR/Chiselo-${VERSION}.dmg"
ICON_DIR="$ROOT_DIR/Chiselo/Resources/AppIcon"
ICON_FILE="$ICON_DIR/Chiselo.icns"
TEAM_ID="JF8T4Y5B5R"
TEAM_NAME="Wuhan Fan Ge Network Technology Co., Ltd."
DEFAULT_DEVELOPER_ID="Developer ID Application: ${TEAM_NAME} (${TEAM_ID})"
SIGNING_IDENTITY="${CODESIGN_IDENTITY:-${SIGN_IDENTITY:-}}"
RELEASE_PREFIX="${CHISELO_R2_PREFIX:-chiselo}"
DOWNLOAD_BASE_URL="${CHISELO_DOWNLOAD_BASE_URL:-https://downloads.vellumloop.com}"
DOWNLOAD_URL="${CHISELO_DOWNLOAD_URL:-}"
SWIFTPM_SCRATCH_PATH="${CHISELO_SWIFTPM_SCRATCH_PATH:-}"
SPARKLE_PUBLIC_KEY="${CHISELO_SPARKLE_PUBLIC_KEY:-}"
SPARKLE_FRAMEWORK="${CHISELO_SPARKLE_FRAMEWORK:-}"
NOTARIZE_DMG="${CHISELO_NOTARIZE:-0}"
NOTARY_KEY="${CHISELO_NOTARY_KEY:-}"
NOTARY_KEY_ID="${CHISELO_NOTARY_KEY_ID:-}"
NOTARY_ISSUER="${CHISELO_NOTARY_ISSUER:-}"
NOTARY_PROFILE="${CHISELO_NOTARY_PROFILE:-}"
BUILD_FINGERPRINT="${CHISELO_BUILD_FINGERPRINT:-}"
BUILD_TIMESTAMP="${CHISELO_BUILD_TIMESTAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

cd "$ROOT_DIR"

compute_build_fingerprint() {
  if [[ -n "$BUILD_FINGERPRINT" ]]; then
    printf '%s\n' "$BUILD_FINGERPRINT"
    return
  fi

  local head
  head="$(git rev-parse --short=12 HEAD 2>/dev/null || true)"
  if [[ -z "$head" ]]; then
    date -u +%Y%m%d%H%M%S
    return
  fi

  if git diff --quiet --ignore-submodules -- && git diff --cached --quiet --ignore-submodules -- && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
    printf '%s\n' "$head"
    return
  fi

  local dirty_hash
  dirty_hash="$(
    {
      git diff --binary --ignore-submodules --
      git diff --cached --binary --ignore-submodules --
      git ls-files --others --exclude-standard | while IFS= read -r path; do
        if [[ "$path" == .build/* || "$path" == outputs/* ]]; then
          continue
        fi
        [[ -f "$path" ]] && shasum -a 256 "$path"
      done
    } | shasum -a 256 | awk '{print substr($1,1,8)}'
  )"
  printf '%s-dirty-%s\n' "$head" "$dirty_hash"
}

BUILD_FINGERPRINT="$(compute_build_fingerprint)"
if [[ -z "$DOWNLOAD_URL" ]]; then
  DOWNLOAD_URL="${DOWNLOAD_BASE_URL%/}/$RELEASE_PREFIX/Chiselo-${VERSION}.dmg?build=$BUILD_FINGERPRINT"
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -F "\"$DEFAULT_DEVELOPER_ID\"" >/dev/null; then
    SIGNING_IDENTITY="$DEFAULT_DEVELOPER_ID"
  else
    SIGNING_IDENTITY="-"
  fi
fi

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  CODESIGN_TIMESTAMP=(--timestamp=none)
  CODESIGN_LABEL="ad-hoc"
else
  CODESIGN_TIMESTAMP=(--timestamp)
  CODESIGN_LABEL="$SIGNING_IDENTITY"
fi

if [[ "$NOTARIZE_DMG" == "1" && "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Apple notarization requires a Developer ID signing identity." >&2
  exit 1
fi

sign_app_bundle() {
  local target="$1"
  codesign --force --deep --options runtime "${CODESIGN_TIMESTAMP[@]}" --sign "$SIGNING_IDENTITY" "$target"
}

sign_app_container() {
  local target="$1"
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --options runtime "${CODESIGN_TIMESTAMP[@]}" \
      --entitlements "$ADHOC_ENTITLEMENTS" \
      --sign "$SIGNING_IDENTITY" "$target"
  else
    codesign --force --options runtime "${CODESIGN_TIMESTAMP[@]}" \
      --sign "$SIGNING_IDENTITY" "$target"
  fi
}

sign_embedded_bundles() {
  local target="$1"
  local signed_count=0
  local bundle_path
  local search_root="$target"

  if [[ -d "$target/Contents" ]]; then
    search_root="$target/Contents"
  fi

  while IFS= read -r bundle_path; do
    [[ "$bundle_path" == "$target" ]] && continue
    sign_app_bundle "$bundle_path"
    signed_count=$((signed_count + 1))
  done < <(find "$search_root" -type d \( \
    -name '*.framework' -o \
    -name '*.app' -o \
    -name '*.xpc' -o \
    -name '*.appex' \
  \) -prune -print | sort -r)

  echo "==> Signed $signed_count embedded bundle(s)"
}

sign_macho_resources() {
  local target="$1"
  local signed_count=0
  local file_path

  while IFS= read -r -d '' file_path; do
    if file "$file_path" | grep -q "Mach-O"; then
      codesign --force --options runtime "${CODESIGN_TIMESTAMP[@]}" --sign "$SIGNING_IDENTITY" "$file_path"
      signed_count=$((signed_count + 1))
    fi
  done < <(find "$target" -type f \
    ! -path '*/_CodeSignature/*' \
    ! -path '*/Contents/MacOS/*' \
    -print0)

  echo "==> Signed $signed_count embedded Mach-O resource(s)"
}

find_sparkle_framework() {
  if [[ -n "$SPARKLE_FRAMEWORK" && -d "$SPARKLE_FRAMEWORK" ]]; then
    printf '%s\n' "$SPARKLE_FRAMEWORK"
    return 0
  fi
  if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR/Sparkle.framework" ]]; then
    printf '%s\n' "$BUILD_DIR/Sparkle.framework"
    return 0
  fi
  if [[ -n "$SWIFTPM_SCRATCH_PATH" ]]; then
    find "$SWIFTPM_SCRATCH_PATH/artifacts/sparkle/Sparkle" -path '*/Sparkle.framework' -type d -print -quit 2>/dev/null
    return 0
  fi
  find "$ROOT_DIR/.build/artifacts/sparkle/Sparkle" -path '*/Sparkle.framework' -type d -print -quit 2>/dev/null
}

copy_sparkle_framework() {
  local framework
  framework="$(find_sparkle_framework)"
  if [[ -z "$framework" || ! -d "$framework" ]]; then
    echo "Missing Sparkle.framework. Run swift build once, or set CHISELO_SPARKLE_FRAMEWORK." >&2
    exit 1
  fi
  mkdir -p "$APP_BUNDLE/Contents/Frameworks"
  rsync -a --delete "$framework" "$APP_BUNDLE/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
}

swift_build() {
  if [[ -n "$SWIFTPM_SCRATCH_PATH" ]]; then
    swift build -c "$BUILD_CONFIG" --scratch-path "$SWIFTPM_SCRATCH_PATH" "$@"
  else
    swift build -c "$BUILD_CONFIG" "$@"
  fi
}

notarize_dmg() {
  local dmg_path="$1"

  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$dmg_path" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait
    return
  fi

  if [[ -z "$NOTARY_KEY" || -z "$NOTARY_KEY_ID" || -z "$NOTARY_ISSUER" ]]; then
    echo "Apple notarization requires CHISELO_NOTARY_KEY, CHISELO_NOTARY_KEY_ID, and CHISELO_NOTARY_ISSUER, or set CHISELO_NOTARY_PROFILE." >&2
    exit 1
  fi

  if [[ ! -f "$NOTARY_KEY" ]]; then
    echo "Missing Apple notarization key file: $NOTARY_KEY" >&2
    exit 1
  fi

  xcrun notarytool submit "$dmg_path" \
    --key "$NOTARY_KEY" \
    --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER" \
    --wait
}

echo "==> Generating design tokens"
node "$ROOT_DIR/scripts/generate-design-tokens.mjs"

echo "==> Building $APP_NAME ($BUILD_CONFIG)"
swift_build
BUILD_DIR="$(swift_build --show-bin-path | tail -n 1)"

if [[ -z "$SPARKLE_PUBLIC_KEY" && -f "$ROOT_DIR/scripts/chiselo-sparkle-tool.swift" ]]; then
  SPARKLE_PUBLIC_KEY="$(swift "$ROOT_DIR/scripts/chiselo-sparkle-tool.swift" public-key 2>/dev/null || true)"
fi
if [[ -z "$SPARKLE_PUBLIC_KEY" || "$SPARKLE_PUBLIC_KEY" == "REPLACE_WITH_CHISELO_SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "Missing Sparkle public key. Run: swift scripts/chiselo-sparkle-tool.swift ensure-key" >&2
  exit 1
fi
ARCH="$(uname -m)"
case "$ARCH" in
  arm64) PUBLIC_ARCH="arm64" ;;
  x86_64) PUBLIC_ARCH="x86_64" ;;
  *) PUBLIC_ARCH="$ARCH" ;;
esac
SPARKLE_FEED_URL="${CHISELO_SPARKLE_FEED_URL:-${DOWNLOAD_BASE_URL%/}/$RELEASE_PREFIX/latest/appcast-$PUBLIC_ARCH.xml}"

echo "==> Generating app icon"
swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$ICON_DIR"

echo "==> Preparing app bundle"
rm -rf "$APP_BUNDLE" "$DMG_STAGING"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp -R "$BUILD_DIR/Chiselo_Chiselo.bundle" "$APP_BUNDLE/Contents/Resources/"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/Chiselo.icns"
copy_sparkle_framework

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>Chiselo</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUNDLE_VERSION</string>
  <key>ChiseloBuildFingerprint</key>
  <string>$BUILD_FINGERPRINT</string>
  <key>ChiseloBuildTimestamp</key>
  <string>$BUILD_TIMESTAMP</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_KEY</string>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSSupportsOpeningDocumentsInPlace</key>
  <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>HTML Document</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.html</string>
        <string>public.xhtml</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Chiselo Project</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.json</string>
        <string>app.chiselo.aislide</string>
      </array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>app.chiselo.aislide</string>
      <key>UTTypeDescription</key>
      <string>Chiselo Project</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.json</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>aislide</string>
        </array>
      </dict>
    </dict>
  </array>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  cat > "$ADHOC_ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
</dict>
</plist>
PLIST
fi

echo "==> Signing app ($CODESIGN_LABEL)"
xattr -cr "$APP_BUNDLE"
sign_macho_resources "$APP_BUNDLE"
sign_embedded_bundles "$APP_BUNDLE"
sign_app_container "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Preparing DMG staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Copying direct app bundle"
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_APP_BUNDLE"
cp -R "$APP_BUNDLE" "$OUTPUT_APP_BUNDLE"

if [[ "$OUTPUT_DIR" != "$DEFAULT_OUTPUT_DIR" ]]; then
  echo "==> Syncing default local app bundle"
  mkdir -p "$DEFAULT_OUTPUT_DIR"
  rm -rf "$DEFAULT_OUTPUT_APP_BUNDLE"
  cp -R "$APP_BUNDLE" "$DEFAULT_OUTPUT_APP_BUNDLE"
fi

if [[ "$NOTARIZE_DMG" == "1" ]]; then
  README_SIGNING_STATUS="$(cat <<'TEXT'
- 当前 App 和 DMG 使用 Developer ID 证书签名。
- 本次打包已启用 Apple notarization，脚本会在 DMG 上 staple 公证票据。
TEXT
)"
  README_SIGNING_STATUS="$README_SIGNING_STATUS
- 安装前可用 xcrun stapler validate Chiselo-${VERSION}.dmg 检查公证票据状态。"
  UPDATE_PACKAGE_STATUS="$(cat <<'TEXT'
- App 和 DMG 使用 Developer ID 签名。
- 本次打包已启用 Apple notarization / stapling。
- App 已内置 Sparkle 热更新入口；更新检查依赖随包写入的 appcast 地址和 Ed25519 公钥。
TEXT
)"
else
  README_SIGNING_STATUS="$(cat <<'TEXT'
- 当前 App 和 DMG 会使用可用的 Developer ID 证书签名。
- 本地打包脚本本次未执行 Apple 公证和 stapling。
- 如果没有另外完成公证，macOS 首次打开时仍可能出现安全提示。
TEXT
)"
  UPDATE_PACKAGE_STATUS="$(cat <<'TEXT'
- App 和 DMG 使用 Developer ID 签名。
- 当前打包未执行 Apple notarization / stapling。
- 正式公开发布前，如果要减少 Gatekeeper 提示，需要额外完成公证并 staple。
- App 已内置 Sparkle 热更新入口；更新检查依赖随包写入的 appcast 地址和 Ed25519 公钥。
TEXT
)"
fi

cat > "$DMG_STAGING/README.txt" <<README
Chiselo
==========

HTML 精修与交付工具

安装方式
--------
1. 打开这个 DMG。
2. 把 Chiselo.app 拖到 Applications 文件夹。
3. 从 Applications 中启动 Chiselo，不建议直接在 DMG 里运行。

签名状态
--------
$README_SIGNING_STATUS

如果首次打开被拦截：

1. 确认已经把 Chiselo.app 拖到 Applications。
2. 在 Finder 的 Applications 里右键点击 Chiselo.app，选择“打开”。
3. 如果系统设置里出现“仍要打开”，进入“系统设置 -> 隐私与安全性”确认打开。

文件说明
--------
- README.txt：安装方式、签名状态和注意事项。
- 更新说明.txt：当前版本的主要变化。

当前能力
--------
- 定位：HTML 精修与交付工具。
- 打开并精修现有或生成的 HTML 页面/文档。
- 可把外部 HTML / HTM / XHTML 文件直接拖进窗口打开。
- 支持在窗口、tab 条、侧栏和中间画布区域拖入文件；画布不再吞掉 HTML 文件拖拽。
- 支持浏览器式多 tab：每个 HTML 或 Chiselo 项目独立保存当前编辑快照，可切换、关闭。
- 支持从 Finder 把 HTML 文件拖到 Chiselo.app 图标，或用“打开方式”直接进入编辑。
- 已内置符合 macOS 的 Chiselo 图标，Finder、Dock、安装包和应用切换器都会显示。
- 支持通过“检查更新…”菜单接入 Sparkle 热更新；正式发布时使用 appcast 自动发现新版本。
- 支持页面、文档、报告、海报、dashboard 和演示式 HTML。
- 自动修复片段式或缺少 html/head/body 包装的 HTML。
- 采用 macOS 毛玻璃风格界面：轻量侧栏、清爽画布背景、统一设计 token。
- 点击画布或对象结构选择内容。
- 画布正文可直接点击选中对象；对象结构只是精细选层级的辅助。
- HTML 直编画布默认一次只选中一个对象，避免编辑一个局部时带动其他对象。
- 双击标题、段落、列表项、表格单元格等文字节点可直接原地编辑；选中文字节点后按 Enter 也可进入编辑。
- 按住 Command 并滚动鼠标滚轮可直接放大/缩小画布，控制点会保持可抓取大小。
- 画布内 hover 提示和选中快捷动作条，可直接编辑文字、替换图片、复制、删除、置顶置底。
- 拖拽、缩放、对齐、铺满、吸附网格、微调。
- 修改文字、替换图片、识别断链图片、增删表格行列、调整单元格样式。
- 左侧交付检查会提示断链资源、复杂表格、SVG 和干净 HTML 状态。
- 表格行列操作包含 rowspan / colspan 合并单元格保护。
- 配套自动视觉 QA 脚本可逐页截图检查越界、遮挡和文本溢出。
- 导出干净 HTML、高保真 PDF、对象级可编辑 PPTX；输出格式服务于最终交付。
- 打开真实 HTML/Chiselo 项目文件时会保留 .chiselo-backup 原始备份；第一次修改前会提醒确认备份；保存覆盖前会写入 .chiselo-history 版本快照。
- 工具栏可打开备份目录，也可确认后恢复最近快照。

注意事项
--------
- 当前是开发预览版。
- 复杂脚本页面、跨域资源、动画和伪元素的深度编辑仍在迭代。
- 若只是试用，请先复制 HTML 文件再打开编辑。
README

cat > "$DMG_STAGING/更新说明.txt" <<README
Chiselo ${VERSION} 更新说明
======================

本地包状态
----------
$UPDATE_PACKAGE_STATUS

本次更新
--------
- 版本号升至 ${VERSION}，Sparkle 使用的 CFBundleVersion 升至 ${BUNDLE_VERSION}。
- 保存、导出和可编辑版转换会锁定发起操作的标签页；操作结束前禁止切换或关闭，避免结果写入其他文档。
- 可编辑版转换失败时保留源标签页内容和未保存状态，不会误标为已保存。
- 恢复历史快照改为临时文件准备、原子替换和失败回滚，恢复失败时保留当前文件。
- 重复导出可编辑 HTML 会替换旧运行时，不再累积重复的样式和脚本块。
- HTML 按原始 100% CSS 像素比例打开；窗口、检查器和对象选择不会触发自动缩放。
- 可编辑版转换按文字片段去重捕获，避免嵌套 HTML 生成重复文字对象。
- 局部文字、字号、行高和内边距修改会锁定当前对象框架，其他模块和后续区域保持不动。
- 内容放不下时进入溢出复核，不再通过撑开布局影响未选对象。
- 自动尺寸保护会在修改审查中单独标记；一键回退文字修改时同时撤销对应保护，不留下多余样式。
- 静态安全模式使用 WebKit 原生规则阻止远程页面、图片、样式、脚本、字体和媒体请求。
- 只有用户明确确认后才进入可信兼容模式，启用脚本、表单和远程资源。
- HTML 与本地 CSS 保存采用事务式写回；部分写入失败时自动回滚。
- 新增正式 XCTest，并以示例页、运营看板、编辑简报和交付表单完成真实 HTML 零连带位移回归。

主要能力
--------
- 打开真实 HTML 或 Chiselo 项目文件时，会保留 .chiselo-backup 原始备份。
- 保存覆盖前会写入 .chiselo-history 版本快照。
- 选中对象的快捷动作保持紧凑，减少遮挡正文内容。
- 支持干净 HTML、高保真 PDF、对象级可编辑 PPTX 导出。
- 支持 Sparkle 热更新检查；公开发布时需要把 DMG 和 appcast 一起上传。
- 在线更新验证会核对版本号、构建号、Feed URL、Ed25519 签名、文件长度和 SHA-256。
README

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  echo "==> Signing DMG ($CODESIGN_LABEL)"
  codesign --force "${CODESIGN_TIMESTAMP[@]}" --sign "$SIGNING_IDENTITY" "$DMG_PATH"
fi

echo "==> Verifying DMG"
hdiutil verify "$DMG_PATH"

if [[ "$NOTARIZE_DMG" == "1" ]]; then
  echo "==> Notarizing DMG with Apple notary service"
  notarize_dmg "$DMG_PATH"
  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  echo "==> Re-verifying stapled DMG"
  hdiutil verify "$DMG_PATH"
fi

APPCAST_PATH="$OUTPUT_DIR/Chiselo-${VERSION}-macOS-${PUBLIC_ARCH}-appcast.xml"
APPCAST_LATEST_DIR="$OUTPUT_DIR/latest"
APPCAST_LATEST_PATH="$APPCAST_LATEST_DIR/appcast-$PUBLIC_ARCH.xml"
echo "==> Writing Sparkle appcast"
mkdir -p "$APPCAST_LATEST_DIR"
swift "$ROOT_DIR/scripts/chiselo-sparkle-tool.swift" write-appcast \
  --output "$APPCAST_PATH" \
  --archive "$DMG_PATH" \
  --download-url "$DOWNLOAD_URL" \
  --short-version "$VERSION" \
  --bundle-version "$BUNDLE_VERSION" \
  --minimum-system-version "13.0" \
  --arch "$PUBLIC_ARCH" \
  --expected-public-key "$SPARKLE_PUBLIC_KEY" \
  --app-name "$APP_NAME" \
  --link "${CHISELO_PRODUCT_URL:-https://downloads.vellumloop.com/chiselo}"
cp "$APPCAST_PATH" "$APPCAST_LATEST_PATH"

echo "Created: $OUTPUT_APP_BUNDLE"
if [[ "$OUTPUT_DIR" != "$DEFAULT_OUTPUT_DIR" ]]; then
  echo "Synced: $DEFAULT_OUTPUT_APP_BUNDLE"
fi
echo "Created: $DMG_PATH"
echo "Created: $APPCAST_PATH"
echo "Created: $APPCAST_LATEST_PATH"
