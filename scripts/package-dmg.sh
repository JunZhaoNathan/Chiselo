#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/outputs}"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/outputs"
APP_NAME="Chiselo"
BUNDLE_ID="app.chiselo.editor"
VERSION="0.1.4"
BUILD_CONFIG="release"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIG"
APP_BUNDLE="$ROOT_DIR/.build/package/$APP_NAME.app"
DMG_STAGING="$ROOT_DIR/.build/dmg-staging"
OUTPUT_APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
DEFAULT_OUTPUT_APP_BUNDLE="$DEFAULT_OUTPUT_DIR/$APP_NAME.app"
DMG_PATH="$OUTPUT_DIR/Chiselo-${VERSION}.dmg"
ICON_DIR="$ROOT_DIR/Chiselo/Resources/AppIcon"
ICON_FILE="$ICON_DIR/Chiselo.icns"

cd "$ROOT_DIR"

echo "==> Generating design tokens"
node "$ROOT_DIR/scripts/generate-design-tokens.mjs"

echo "==> Building $APP_NAME ($BUILD_CONFIG)"
swift build -c "$BUILD_CONFIG"

echo "==> Generating app icon"
swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$ICON_DIR"

echo "==> Preparing app bundle"
rm -rf "$APP_BUNDLE" "$DMG_STAGING"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp -R "$BUILD_DIR/Chiselo_Chiselo.bundle" "$APP_BUNDLE/Contents/Resources/"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/Chiselo.icns"

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
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
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
      <string>Chiselo Deck</string>
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
      <string>Chiselo Deck</string>
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

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_BUNDLE"

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

cat > "$DMG_STAGING/README.txt" <<'README'
Chiselo
==========

Chisel your HTML

安装方式
--------
1. 打开这个 DMG。
2. 把 Chiselo.app 拖到 Applications 文件夹。
3. 从 Applications 中启动 Chiselo。

首次打开提示
------------
这是本地打包的未公证版本。第一次安装如果 macOS 拦住，请先看同目录里的：

- 首次打开帮助.txt

最常见的解决方式：

1. 先把 Chiselo.app 拖到 Applications 再打开。
2. 在 Finder 中右键点击 Chiselo.app，选择“打开”，再确认一次。
3. 如果系统设置里出现“仍要打开”，点它即可。

当前能力
--------
- 定位：HTML 主资产 + Office 软件式可视化编辑层 + 多格式输出。
- 打开并直接编辑任意 HTML 文档。
- 可把外部 HTML / HTM / XHTML 文件直接拖进窗口打开。
- 支持在窗口、tab 条、侧栏和中间 WebView 画布区域拖入文件；画布不再吞掉 HTML 文件拖拽。
- 支持浏览器式多 tab：每个 HTML 或 deck 独立保存当前编辑快照，可切换、关闭。
- 支持从 Finder 把 HTML 文件拖到 Chiselo.app 图标，或用“打开方式”直接进入编辑。
- 已内置符合 macOS 的 Chiselo 图标，Finder、Dock、安装包和应用切换器都会显示。
- 支持 AI 生成或已有的 HTML 页面、A4 文档、海报、dashboard、HTML slides。
- 自动修复片段式或缺少 html/head/body 包装的 AI HTML。
- 采用 macOS 毛玻璃风格界面：轻量侧栏、清爽画布背景、统一设计 token。
- 点击画布或 DOM 树选择元素。
- 画布正文可直接点击选中元素；DOM 树只是精细选层级的辅助。
- 双击标题、段落、列表项、表格单元格等文字节点可直接原地编辑；选中文字节点后按 Enter 也可进入编辑。
- 按住 Command 并滚动鼠标滚轮可直接放大/缩小画布，控制点会保持可抓取大小。
- 画布内 hover 提示和选中快捷动作条，可直接编辑文字、替换图片、复制、删除、置顶置底。
- Shift/Cmd 点选可多选真实 DOM，支持同类选择、子元素选择和组合调整。
- 拖拽、缩放、对齐、铺满、吸附网格、微调。
- 修改文字、替换图片、识别断链图片、增删表格行列、调整单元格样式。
- 左侧交付检查会提示断链资源、复杂表格、SVG 和干净 HTML 状态。
- 表格行列操作包含 rowspan / colspan 合并单元格保护。
- 配套自动视觉 QA 脚本可逐页截图检查越界、遮挡和文本溢出。
- 导出干净 HTML、高保真 PDF、对象级可编辑 PPTX；输出格式服务于 HTML 主资产的最终交付。
- 打开真实 HTML/deck 文件时会保留 .chiselo-backup 原始备份；保存覆盖前会写入 .chiselo-history 版本快照。
- 工具栏可打开备份目录，也可确认后恢复最近快照。

注意事项
--------
- 当前是开发预览版。
- 复杂脚本页面、跨域资源、动画和伪元素的深度编辑仍在迭代。
- 若只是试用，请先复制 HTML 文件再打开编辑。
README

cat > "$DMG_STAGING/首次打开帮助.txt" <<'README'
Chiselo 首次打开帮助
=====================

如果你是第一次安装 Chiselo，macOS 可能会提示：

- “无法验证开发者”
- “已损坏，应该移到废纸篓”
- “无法打开，因为 Apple 无法检查其是否包含恶意软件”

这通常不是文件坏了，而是因为当前预览版还没有做 Apple 公证。

推荐按下面顺序尝试：

方案 1：右键打开
----------------
1. 先把 Chiselo.app 拖到 Applications。
2. 打开 Finder -> Applications。
3. 找到 Chiselo.app。
4. 右键点击它，选择“打开”。
5. 系统再次提示时，再点一次“打开”。

这是最简单、最推荐的方式。

方案 2：系统设置里点“仍要打开”
-----------------------------
1. 先尝试双击一次 Chiselo.app。
2. 出现拦截提示后，打开：
   系统设置 -> 隐私与安全性
3. 向下滚动到安全区域。
4. 如果看到 Chiselo 被拦截，点击“仍要打开”。
5. 再次确认打开。

方案 3：如果提示“移到废纸篓”或“已损坏”
--------------------------------------
有些 macOS 版本会把未公证应用直接说成“已损坏”。如果你确认这个 App 是从 GitHub Release 下载的，可以在终端执行：

```bash
xattr -dr com.apple.quarantine /Applications/Chiselo.app
```

执行后，再回到 Applications 里双击或右键打开。

方案 4：从源码运行
------------------
如果你熟悉命令行，也可以直接从源码启动：

```bash
swift run Chiselo
```

需要：

- macOS 13 或更高
- Xcode Command Line Tools
- Swift 5.9 或更高

补充提醒
--------
- 请优先从 GitHub Release 下载官方 DMG。
- 第一次打开时，最好先把 App 拖到 Applications，不要直接在 DMG 里运行。
- 如果依然无法打开，重新下载 DMG 再试一次。
README

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "==> Verifying DMG"
hdiutil verify "$DMG_PATH"

echo "Created: $OUTPUT_APP_BUNDLE"
if [[ "$OUTPUT_DIR" != "$DEFAULT_OUTPUT_DIR" ]]; then
  echo "Synced: $DEFAULT_OUTPUT_APP_BUNDLE"
fi
echo "Created: $DMG_PATH"
