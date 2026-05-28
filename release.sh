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
DMG_PATH="$RELEASE_DIR/FundBar-macOS.dmg"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

rm -rf "$DERIVED_DATA" "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    build

APP_PATH="$DERIVED_DATA/Build/Products/Release/FundBar.app"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv -t exec "$APP_PATH" || true

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname FundBar \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo "$DMG_PATH"
