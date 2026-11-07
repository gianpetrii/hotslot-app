#!/usr/bin/env bash
# Descargas del DMG por versión (contador de GitHub Releases).
# Incluye tus propias pruebas y las descargas que hace Sparkle al actualizar.
set -euo pipefail

REPO="${REPO:-gianpetrii/hotslot-app}"

gh api "repos/$REPO/releases" --paginate --jq '
  .[] | [.tag_name, ([.assets[] | select(.name | endswith(".dmg")) | .download_count] | add // 0)] | @tsv
' | tee /tmp/hotslot-downloads.tsv | column -t -s $'\t'

echo "---"
awk -F'\t' '{ total += $2 } END { printf "Total: %d\n", total }' /tmp/hotslot-downloads.tsv
