#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT_DIR/FundBar.xcodeproj"
SCHEME="FundBar"
DERIVED_DATA="${DERIVED_DATA:-/tmp/FundBar-Release-DerivedData}"
RELEASE_DIR="$ROOT_DIR/release"
STAGING_DIR="$(mktemp -d)"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Xingtai Muge Information Technology Co., Ltd. (99M5SZBF38)}"
TEAM_ID="${TEAM_ID:-99M5SZBF38}"
# 公证凭据：钥匙串里存的 profile（一次性运行 `xcrun notarytool store-credentials` 存入）
NOTARY_PROFILE="${NOTARY_PROFILE:-FundBar-Notary}"
# NOTARIZE=0 只签名不公证
NOTARIZE="${NOTARIZE:-1}"
DMG_PATH="$RELEASE_DIR/FundBar-macOS.dmg"
NOTARY_ZIP=""

cleanup() {
    rm -rf "$STAGING_DIR"
    [ -n "$NOTARY_ZIP" ] && rm -f "$NOTARY_ZIP"
}
trap cleanup EXIT

rm -rf "$DERIVED_DATA" "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# ---------- 1. 构建（手动签名 + hardened runtime，公证必需）----------
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
    build

APP_PATH="$DERIVED_DATA/Build/Products/Release/FundBar.app"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv -t exec "$APP_PATH" || true

# ---------- 2. 公证 app 并订书钉 ----------
if [ "$NOTARIZE" != "0" ]; then
    echo "→ 提交 app 公证（profile: $NOTARY_PROFILE）…"
    NOTARY_ZIP="$(mktemp -t FundBar).zip"
    ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"
    xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"
fi

# ---------- 3. 用已公证的 app 打 DMG ----------
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname FundBar \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# ---------- 4. 签 DMG ----------
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

# ---------- 5. 公证 DMG 并订书钉 ----------
if [ "$NOTARIZE" != "0" ]; then
    echo "→ 提交 DMG 公证…"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
fi

# ---------- 6. 校验 ----------
codesign --verify --verbose=2 "$DMG_PATH"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"
if [ "$NOTARIZE" != "0" ]; then
    xcrun stapler validate "$DMG_PATH"
fi

echo "$DMG_PATH"
