#!/usr/bin/env bash
# Despliega docs/ a Vercel (proyecto hotslot-app-docs).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS="$ROOT/docs"

cd "$DOCS"

if [[ -z "${VERCEL_TOKEN:-}" ]]; then
  echo "→ Login interactivo (npx vercel login) si hace falta"
fi

echo "→ Deploy docs/ → production (proyecto vinculado en docs/.vercel tras el primer deploy)"
npx --yes vercel@latest deploy --prod --yes

echo "✓ Sitio: https://hotslot-app-docs.vercel.app/"
