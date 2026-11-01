# Handoff de diseño (Dante)

El paquete **no está en Git**. Los assets viven en Google Drive:

**Carpeta compartida:** [slots-handoff (Drive)](https://drive.google.com/drive/folders/1sNJnRxqazawSPMFkRs3up5D1INZxSpJB?usp=sharing)

## Qué subir a esa carpeta (Gianluca)

Subí **un solo archivo** para mantenerlo simple:

| Archivo | Origen local | Notas |
|---------|----------------|--------|
| **`slots-handoff.zip`** | Comprimí la carpeta `docs/slots-handoff/` de tu Mac (la que descomprimiste del paquete de Dante) | ~66 MB. Debe contener `01-docs/`, `02-diseno/`, `03-marca/`, `04-marketing/`, `05-flujos/`, `LEEME.md`, `PROMPT-CURSOR.md`. |

Comando para generar el zip (desde la raíz del repo, si tenés la carpeta descomprimida):

```bash
cd docs && ditto -c -k --sequesterRsrc --keepParent slots-handoff slots-handoff.zip
```

Subí **`slots-handoff.zip`** a la carpeta de Drive (no hace falta subir cientos de PNG sueltos).

Opcional en la misma carpeta: un **`LEEME.txt`** de una línea: “Descomprimí `slots-handoff.zip` en `docs/` del repo para consultar flujos y HTML.”

## Uso local (desarrollo / Cursor)

```bash
cd docs
curl -L -o slots-handoff.zip '<enlace directo de descarga del zip en Drive, cuando exista>'
unzip -q slots-handoff.zip
```

O descargá el zip desde Drive con el navegador y descomprimilo en `docs/`.

Xcode **no** necesita el handoff para compilar; sirve para copy, medidas y pantallas durante el rediseño.

`docs/slots-handoff/` y `docs/slots-handoff*.zip` locales están en `.gitignore`.
