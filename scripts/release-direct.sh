#!/usr/bin/env bash
# Archive HotSlot, export Developer ID .app, notarize and staple.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="HotSlot"
ARCHIVE_PATH="$ROOT/build/HotSlot.xcarchive"
EXPORT_DIR="$ROOT/build/release"
EXPORT_OPTIONS="$ROOT/scripts/ExportOptions-developer-id.plist"
TEAM_ID="${DEVELOPMENT_TEAM:-53M8KYX8G4}"

MARKETING_VERSION="$(grep MARKETING_VERSION project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"

require_developer_id() {
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
    return 0
  fi
  echo "❌ No hay certificado «Developer ID Application» en el llavero." >&2
  echo "   Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application" >&2
  echo "   Guía: docs/RELEASE_FIRST_TIME.md" >&2
  exit 1
}

require_developer_id

if [[ -z "${DEVELOPER_ID:-}" ]]; then
  DEVELOPER_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)"
fi
if [[ -z "$DEVELOPER_ID" ]]; then
  echo "❌ Definí DEVELOPER_ID o creá el certificado Developer ID Application." >&2
  exit 1
fi

echo "→ Firmando con: $DEVELOPER_ID"

echo "→ xcodegen"
xcodegen generate

mkdir -p "$ROOT/build"

echo "→ Archive (Release)"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID"

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

echo "→ Export Developer ID"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

APP="$EXPORT_DIR/HotSlot.app"
if [[ ! -d "$APP" ]]; then
  echo "❌ No se encontró $APP" >&2
  exit 1
fi

ZIP="$EXPORT_DIR/HotSlot-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_PASSWORD:-}" && -n "${NOTARY_TEAM_ID:-}" ]]; then
  echo "→ Notarize (puede tardar unos minutos)"
  xcrun notarytool submit "$ZIP" \
    --apple-id "$NOTARY_APPLE_ID" \
    --password "$NOTARY_PASSWORD" \
    --team-id "$NOTARY_TEAM_ID" \
    --wait
  echo "→ Staple"
  xcrun stapler staple "$APP"
  if [[ -f "$EXPORT_DIR/HotSlot-${MARKETING_VERSION}.dmg" ]]; then
    xcrun stapler staple "$EXPORT_DIR/HotSlot-${MARKETING_VERSION}.dmg" 2>/dev/null || true
  fi
else
  echo "⚠️  Sin notarización: export NOTARY_APPLE_ID, NOTARY_PASSWORD, NOTARY_TEAM_ID"
  echo "   Ver docs/RELEASE_FIRST_TIME.md"
fi

DMG="$EXPORT_DIR/HotSlot-${MARKETING_VERSION}.dmg"
if command -v create-dmg >/dev/null; then
  echo "→ create-dmg"
  rm -f "$DMG"
  create-dmg \
    --volname "HotSlot" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 128 \
    --app-drop-link 400 185 \
    "$DMG" \
    "$APP"
else
  echo "⚠️  Instalá create-dmg para generar .dmg: brew install create-dmg"
fi

if command -v shasum >/dev/null; then
  if [[ -f "$DMG" ]]; then
    shasum -a 256 "$DMG" | tee "$EXPORT_DIR/SHA256.txt"
  else
    shasum -a 256 "$ZIP" | tee "$EXPORT_DIR/SHA256.txt"
  fi
fi

echo ""
echo "✓ App: $APP"
[[ -f "$DMG" ]] && echo "✓ DMG: $DMG"
echo "  Subir: gh release upload v${MARKETING_VERSION} \"$DMG\" build/release/SHA256.txt"
