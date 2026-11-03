# Sitio estático (`docs/`)

## Landing principal

- **Fuente de diseño:** `docs/slots-landing/` (Dante). El sitio publicado usa **`docs/index.html`** (copia integrada con enlaces a beta y privacidad).
- **Instrucciones del paquete:** `docs/slots-landing/LEEME.md` (waitlist, campañas `#tiktok`, etc.).

## Otras páginas (mantener)

| Archivo | Uso |
|---------|-----|
| `privacy.html` | Política de privacidad |
| `purchase.html` | Lemon / licencia (cuando aplique) |
| `appcast.xml` | Sparkle |
| `hotslot.css` | Estilos de `privacy.html` / `purchase.html` |

## Deploy

Vercel sirve la carpeta `docs/` (ver `vercel.json`). Tras cambios: push a `main` y verificar el deploy.

## Config en `index.html`

- `WAITLIST_ENDPOINT` — URL Formspree (vacío = formulario muestra error amigable hasta configurar).
- `BETA_RELEASE_URL` — GitHub Releases (latest).
- `VIDEO_SRC` — opcional, mp4 en la misma carpeta.
