# Docs en Vercel

Sitio público: **https://hotslot-app-docs.vercel.app/**

El repo puede ser **privado**; Vercel sirve solo la carpeta `docs/`.

## Primera vez (dashboard)

1. [vercel.com](https://vercel.com) → **Add New Project** → importar **gianpetrii/hotslot-app**
2. **Root Directory:** `docs` (Edit → seleccionar carpeta `docs`)
3. **Framework Preset:** Other (sin build command)
4. **Output:** archivos estáticos en la raíz del root directory
5. **Project Name:** `hotslot-app-docs` (para conservar el dominio `.vercel.app`)
6. Deploy

Cada push a `main` que toque `docs/` redeploya solo si activás **Production Branch = main** en Settings → Git.

## Desde terminal

```bash
npx vercel login
./scripts/deploy-docs-vercel.sh
```

O con token CI (`VERCEL_TOKEN` en [Account Settings → Tokens](https://vercel.com/account/tokens)).

## Archivos servidos

| URL | Archivo |
|-----|---------|
| `/` | `index.html` (landing) |
| `/privacy.html` | Política de privacidad |
