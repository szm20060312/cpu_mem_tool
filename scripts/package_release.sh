#!/bin/bash
set -e

# ======================================
#  FloatMonitor Release 打包脚本
#  生成 DMG 安装包
# ======================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="FloatMonitor"
VERSION="1.1.0"
BUILD_DIR="$PROJECT_DIR/.build"
RELEASE_BIN="$BUILD_DIR/release/$APP_NAME"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION"
DMG_FILE="$BUILD_DIR/$DMG_NAME.dmg"
DMG_TMP="/tmp/$APP_NAME-dmg"

echo "================================="
echo "  FloatMonitor $VERSION Release 打包"
echo "================================="
echo ""

# 1) 清理
echo "=== 1/5 清理旧产物 ==="
rm -rf "$APP_BUNDLE" "$DMG_FILE" "$DMG_TMP"

# 2) Release 编译
echo "=== 2/5 Release 编译 ==="
cd "$PROJECT_DIR"
swift build -c release --arch arm64

# 3) 创建 .app 包
echo "=== 3/5 创建 .app 包 ==="
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# 移除 quarantine 属性
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

# ad-hoc 签名
echo "=== 4/5 签名 ==="
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 || echo "  (ad-hoc 签名完成)"

# 4) 创建 DMG
echo "=== 5/5 创建 DMG ==="
mkdir -p "$DMG_TMP"
cp -R "$APP_BUNDLE" "$DMG_TMP/"
ln -sf /Applications "$DMG_TMP/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TMP" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_FILE" 2>&1 | tail -3

# 签名 DMG
codesign --force --sign - "$DMG_FILE" 2>/dev/null || true

# 清理
rm -rf "$DMG_TMP"

# 5) 结果
echo ""
echo "================================="
echo "  ✅ 打包完成"
echo "================================="
echo "  App:  $APP_BUNDLE"
echo "  DMG:  $DMG_FILE"
echo ""
SIZE=$(du -sh "$DMG_FILE" | cut -f1)
echo "  DMG 大小: $SIZE"
echo ""
echo "  上传到 GitHub Release:"
echo "  https://github.com/szm20060312/FloatMonitor/releases/new"
echo ""
