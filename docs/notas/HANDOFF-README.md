# Handoff de diseño (Dante)

El paquete **no está en Git**. Los assets viven en Google Drive:

**Carpeta compartida (link estable):** [slots-handoff (Drive)](https://drive.google.com/drive/folders/1sNJnRxqazawSPMFkRs3up5D1INZxSpJB?usp=sharing)

El repo **solo referencia esta carpeta**. Si Dante manda un handoff nuevo, subís otro zip acá (mismo nombre `slots-handoff.zip` o `slots-handoff-2026-11.zip`) **sin cambiar el link** en Git.

## Qué subir a esa carpeta (Gianluca)

Subí **un solo archivo** para mantenerlo simple:

| Archivo | Origen local | Notas |
|---------|----------------|--------|
| **`slots-handoff.zip`** | Comprimí la carpeta `dante/entregas/2026-11-01-handoff-completo/` de tu Mac (la que descomprimiste del paquete de Dante) | ~66 MB. Debe contener `01-docs/`, `02-diseno/`, `03-marca/`, `04-marketing/`, `05-flujos/`, `LEEME.md`, `PROMPT-CURSOR.md`. |

Comando para generar el zip (desde la raíz del repo, si tenés la carpeta descomprimida):

```bash
cd docs && ditto -c -k --sequesterRsrc --keepParent slots-handoff slots-handoff.zip
```

Subí **`slots-handoff.zip`** a la carpeta de Drive (no hace falta subir cientos de PNG sueltos).

Opcional en la misma carpeta: un **`LEEME.txt`** de una línea: “Descomprimí `slots-handoff.zip` en `docs/` del repo para consultar flujos y HTML.”

## Uso local (desarrollo / Cursor)

1. Abrí la carpeta de Drive y descargá el zip más reciente (`slots-handoff.zip` o el que subas).
2. Dejá el zip en `dante/zips/` y descomprimilo en `dante/entregas/AAAA-MM-DD-nombre/`.

Xcode **no** necesita el handoff para compilar; sirve para copy, medidas y pantallas durante el rediseño.

## Carpeta local `dante/` (ignorada por Git)

Todo lo que se intercambia con Dante vive en un solo lugar, en la raíz del repositorio (fuera de `docs/`, que es lo que se publica en la web):

- `zips/`: los zips tal como llegan, con la fecha de recepción al principio del nombre.
- `entregas/`: una carpeta por entrega, con la fecha de recepción y un nombre que dice de qué se trata (por ejemplo `2026-11-18-tutorial-v5/`). Ordenadas por nombre quedan en orden cronológico.
- `LEEME.md`: índice de las entregas.

Nada de esto se sube a GitHub: lo que se implemente se documenta en `CHANGELOG.md` y `BACKLOG.md`.
