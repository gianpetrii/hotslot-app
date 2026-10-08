# Primera release directa (HotSlot 0.16.0+)

## 1. Certificado Developer ID (una vez)

Sin esto macOS no confía en el `.dmg` fuera de tu Mac.

1. Abrí **Xcode** → **Settings** → **Accounts** → tu Apple ID → **Manage Certificates…**
2. **+** → **Developer ID Application**
3. Verificá en terminal:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

Deberías ver algo como:

`Developer ID Application: Tu Nombre (53M8KYX8G4)`

## 2. Contraseña para notarización (una vez)

1. [appleid.apple.com](https://appleid.apple.com) → **Contraseñas de app**
2. Generá una para **notarytool** / **Xcode**
3. Guardala (formato `xxxx-xxxx-xxxx-xxxx`) — no es tu contraseña de Apple ID

## 3. Variables de entorno

En la terminal (o en `~/.zshrc` si querés):

```bash
export DEVELOPMENT_TEAM="53M8KYX8G4"
export DEVELOPER_ID="Developer ID Application: Gianluca Petri (53M8KYX8G4)"   # ajustá el nombre exacto del paso 1
export NOTARY_APPLE_ID="gianluca.petri.98@icloud.com"
export NOTARY_TEAM_ID="53M8KYX8G4"
export NOTARY_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

## 4. Build + notarize + DMG

```bash
cd /Users/gianlucapetri/Documents/proyectos/hotslot-app
brew install create-dmg   # opcional, para .dmg bonito
./scripts/release-direct.sh
```

Salida:

- `build/release/HotSlot.app`
- `build/release/HotSlot-notarize.zip`
- `build/release/HotSlot-0.16.0.dmg` (si `create-dmg` está instalado)
- `build/release/SHA256.txt`

## 5. Subir a GitHub Release

```bash
gh release upload v0.16.0 \
  build/release/HotSlot-0.16.0.dmg \
  build/release/SHA256.txt
```

Actualizá la landing si hace falta el enlace directo al `.dmg` en las release notes.

## Problemas frecuentes

| Error | Qué hacer |
|-------|-----------|
| No aparece Developer ID en `find-identity` | Crear certificado en Xcode (paso 1) |
| Export falla signing | `DEVELOPER_ID` debe coincidir **exacto** con el nombre del certificado |
| Notarize Invalid | Revisá app-specific password y Team ID |
| Gatekeeper al abrir | Falta `stapler staple` — el script lo hace si notarize OK |
