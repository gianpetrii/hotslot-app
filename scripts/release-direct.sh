#!/usr/bin/env bash
# Archive HotSlot, export Developer ID .app, notarize and staple.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="HotSlot"
ARCHIVE_PATH="$ROOT/build/HotSlot.xcarchive"
EXPORT_DIR="$ROOT/build/release"
EXPORT_OPTIONS="$ROOT/scripts/ExportOptions-developer-id.plist"

MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :MARKETING_VERSION' project.yml 2>/dev/null || true)"
if [[ -z "$MARKETING_VERSION" ]]; then
  MARKETING_VERSION="$(grep MARKETING_VERSION project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
fi

echo "→ xcodegen"
xcodegen generate

mkdir -p "$ROOT/build"

echo "→ Archive (Release)"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGN_STYLE=Manual \
  ${DEVELOPER_ID:+CODE_SIGN_IDENTITY="$DEVELOPER_ID"} \
  ${DEVELOPMENT_TEAM:+DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"}

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  cat > "$EXPORT_OPTIONS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
PLIST
fi

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

echo "→ Export Developer ID"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  ${DEVELOPER_ID:+CODE_SIGN_IDENTITY="$DEVELOPER_ID"}

APP="$EXPORT_DIR/HotSlot.app"
if [[ ! -d "$APP" ]]; then
  echo "No se encontró $APP" >&2
  exit 1
fi

ZIP="$EXPORT_DIR/HotSlot-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_PASSWORD:-}" && -n "${NOTARY_TEAM_ID:-}" ]]; then
  echo "→ Notarize"
  xcrun notarytool submit "$ZIP" \
    --apple-id "$NOTARY_APPLE_ID" \
    --password "$NOTARY_PASSWORD" \
    --team-id "$NOTARY_TEAM_ID" \
    --wait
  echo "→ Staple"
  xcrun stapler staple "$APP"
else
  echo "⚠️  Omitiendo notarización (definí NOTARY_APPLE_ID, NOTARY_PASSWORD, NOTARY_TEAM_ID)"
fi

if command -v shasum >/dev/null; then
  shasum -a 256 "$ZIP" | tee "$EXPORT_DIR/SHA256.txt"
fi

if command -v create-dmg >/dev/null; then
  DMG="$EXPORT_DIR/HotSlot-${MARKETING_VERSION}.dmg"
  echo "→ create-dmg"
  create-dmg --overwrite --volname "HotSlot" "$DMG" "$APP" || true
fi

echo "✓ Listo: $APP"
