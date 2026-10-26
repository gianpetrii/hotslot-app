#!/usr/bin/env bash
# Archive HotSlot, export Developer ID .app, notarize and staple.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="HotSlot"
ARCHIVE_PATH="$ROOT/build/HotSlot.xcarchive"
EXPORT_DIR="$ROOT/build/release"
EXPORT_OPTIONS="$ROOT/scripts/ExportOptions-developer-id.plist"

# Credenciales locales: scripts/release.env.local (ver release.env.example)
RELEASE_ENV_LOCAL="$ROOT/scripts/release.env.local"
if [[ -f "$RELEASE_ENV_LOCAL" ]]; then
  echo "→ Cargando $(basename "$RELEASE_ENV_LOCAL")"
  set -a
  # shellcheck disable=SC1090
  source "$RELEASE_ENV_LOCAL"
  set +a
fi

TEAM_ID="${DEVELOPMENT_TEAM:-$(grep DEVELOPMENT_TEAM project.yml | head -1 | awk '{print $2}')}"
TEAM_ID="${TEAM_ID:-53M8KYX8G4}"
NOTARY_TEAM_ID="${NOTARY_TEAM_ID:-$TEAM_ID}"

MARKETING_VERSION="$(awk -F': *' '/MARKETING_VERSION:/ { gsub(/"/, "", $2); print $2; exit }' project.yml)"
APP_PRODUCT_NAME="$(awk '/PRODUCT_NAME:/ && !/FULL_PRODUCT_NAME/ { print $2; exit }' project.yml)"

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

DID_NOTARIZE=0
if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  echo "→ Notarize (perfil «${NOTARY_KEYCHAIN_PROFILE}», puede tardar unos minutos)"
  xcrun notarytool submit "$ZIP" \
    --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
    --wait
  echo "→ Staple"
  xcrun stapler staple "$APP"
  DID_NOTARIZE=1
elif [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_PASSWORD:-}" && -n "${NOTARY_TEAM_ID:-}" ]]; then
  echo "→ Notarize (puede tardar unos minutos)"
  xcrun notarytool submit "$ZIP" \
    --apple-id "$NOTARY_APPLE_ID" \
    --password "$NOTARY_PASSWORD" \
    --team-id "$NOTARY_TEAM_ID" \
    --wait
  echo "→ Staple"
  xcrun stapler staple "$APP"
  DID_NOTARIZE=1
else
  echo "⚠️  Sin notarización: creá scripts/release.env.local (ver scripts/release.env.example)"
  echo "   o exportá NOTARY_* / NOTARY_KEYCHAIN_PROFILE"
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

# Notarizamos el .app (zip); el ticket va en Slots.app. El .dmg es solo contenedor — no hace falta staple en el DMG.
if [[ "$DID_NOTARIZE" -eq 1 && -f "$DMG" ]]; then
  echo "→ DMG listo (app dentro ya notarizada y stapleada)"
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
