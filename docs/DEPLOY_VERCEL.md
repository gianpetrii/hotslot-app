# Docs en Vercel

- **Proyecto:** [hotslot-app-docs](https://vercel.com/gianpetriis-projects/hotslot-app-docs)
- **URL pública:** https://hotslot-app-docs.vercel.app/

El repo **gianpetrii/hotslot-app** puede ser privado; Vercel solo publica la carpeta `docs/`.

## Conectar Git (deploy automático en cada push a `main`)

1. Abrí [hotslot-app-docs → Settings → Git](https://vercel.com/gianpetriis-projects/hotslot-app-docs/settings/git)
2. **Connect Git Repository** → **gianpetrii/hotslot-app**
3. [Settings → General → Root Directory](https://vercel.com/gianpetriis-projects/hotslot-app-docs/settings/general) → **Edit** → `docs`
4. [Settings → Build and Deployment](https://vercel.com/gianpetriis-projects/hotslot-app-docs/settings/build-and-deployment):
   - **Framework Preset:** Other
   - **Build Command:** vacío
   - **Output Directory:** vacío (los HTML están en la raíz de `docs/`)
   - **Production Branch:** `main`
5. **Deployments** → **Redeploy** (último commit de `main`)

Si el overview dice *“No Production Deployment”* pero la URL responde, igual conviene completar Git + Root Directory para que los próximos pushes actualicen solos.

## Deploy manual (CLI)

```bash
cd docs
npx vercel login
npx vercel link   # elegir team gianpetriis-projects → proyecto hotslot-app-docs
npx vercel --prod
```

O desde la raíz: `./scripts/deploy-docs-vercel.sh` (después de `vercel link` en `docs/`).

## Comprobar contenido

| URL | Qué deberías ver |
|-----|------------------|
| https://hotslot-app-docs.vercel.app/ | Landing “HotSlot — Clipboard manager” |
| https://hotslot-app-docs.vercel.app/privacy.html | “Última actualización: 8 de octubre de 2026” y **Accesibilidad** |

## Archivos

| Ruta | Archivo |
|------|---------|
| `/` | `index.html` |
| `/privacy.html` | Política de privacidad |

Config: `docs/vercel.json`
