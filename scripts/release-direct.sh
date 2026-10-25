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
APP_PRODUCT_NAME="$(grep 'PRODUCT_NAME:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"

resolve_developer_id() {
  local from_keychain
  from_keychain="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)"
  if [[ -z "$from_keychain" ]]; then
    echo "❌ No hay certificado «Developer ID Application» en el llavero." >&2
    echo "   Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application" >&2
    echo "   Ver README.md → Release (mantenedor)" >&2
    exit 1
  fi
  if [[ -n "${DEVELOPER_ID:-}" && "$DEVELOPER_ID" != *"…"* && "$DEVELOPER_ID" != *"..."* ]]; then
    if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$DEVELOPER_ID"; then
      echo "$DEVELOPER_ID"
      return
    fi
    echo "⚠️  DEVELOPER_ID no válido en el llavero; uso autodetect." >&2
  fi
  echo "$from_keychain"
}

DEVELOPER_ID="$(resolve_developer_id)"
echo "→ Developer ID: $DEVELOPER_ID"

echo "→ xcodegen"
xcodegen generate

mkdir -p "$ROOT/build"

echo "→ Archive (Release, firma automática — export Developer ID después)"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

echo "→ Export Developer ID"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

APP="$EXPORT_DIR/${APP_PRODUCT_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "❌ No se encontró $APP" >&2
  exit 1
fi

ZIP="$EXPORT_DIR/${APP_PRODUCT_NAME}-notarize.zip"
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
  if [[ -f "$EXPORT_DIR/${APP_PRODUCT_NAME}-${MARKETING_VERSION}.dmg" ]]; then
    xcrun stapler staple "$EXPORT_DIR/${APP_PRODUCT_NAME}-${MARKETING_VERSION}.dmg" 2>/dev/null || true
  fi
else
  echo "⚠️  Sin notarización: export NOTARY_APPLE_ID, NOTARY_PASSWORD, NOTARY_TEAM_ID"
  echo "   Ver README.md → Release (mantenedor)"
fi

DMG="$EXPORT_DIR/${APP_PRODUCT_NAME}-${MARKETING_VERSION}.dmg"
if command -v create-dmg >/dev/null; then
  echo "→ create-dmg"
  rm -f "$DMG"
  create-dmg \
    --volname "$APP_PRODUCT_NAME" \
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
