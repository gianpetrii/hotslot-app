---
alwaysApply: true
---

# Reglas del Proyecto

## Gestión de Dependencias

**NUNCA instalar paquetes directamente**
- ❌ No ejecutar `npm install`, `npm add`, `yarn add`, `pnpm add`, etc.
- ✅ Proporcionar el comando exacto para que el usuario lo ejecute
- Ejemplo: "Necesitas instalar X. Ejecuta: `npm install nombre-paquete`"

## Control de Versiones

**NUNCA versionar código automáticamente**
- ❌ No ejecutar `git add`, `git commit`, `git push` sin solicitud explícita
- ✅ Solo versionar cuando el usuario lo pida explícitamente
- ⚠️ No asumir que porque se pidió una vez, todo debe versionarse automáticamente
- Esperar instrucción explícita cada vez: "versiona los cambios", "commitea esto", etc.

## Uso de Terminales

**El usuario ejecuta y valida el flujo de desarrollo; el agente investiga y entrega código.**

Motivo: comandos verbosos (`build`, `dev`, `install`, tests, lint) generan mucha salida y consumen tokens innecesarios. El agente **nunca** los corre: pasa el comando exacto, pide que el usuario lo ejecute y espera el resultado (éxito, o solo el error relevante — sin log completo).

**Permitido sin pedir:**
- Comandos de lectura y diagnóstico cortos: `git status`, `git diff`, `git log`, inspección de archivos, búsqueda en el código, etc.

**Prohibido (pedir al usuario el comando exacto y esperar su respuesta):**
- ❌ `pnpm`/`npm`/`yarn`: `install`, `add`, `dev`, `build`, `test`, `lint` y equivalentes
- ❌ Servidores o procesos largos en background
- ❌ Cualquier comando que suela volcar mucha salida a la terminal

**Git (solo con pedido explícito de versionar):**
- ❌ `git add`, `git commit`, `git push` sin solicitud explícita
- ✅ Si el usuario pide versionar, el agente puede correr git; si prefiere hacerlo él, pasarle los comandos

## Estimación de Tareas

**Estimar basándose en capacidad del agente, no en desarrolladores humanos**
- ✅ Pensar en cuántas tool calls y pasos requiere la tarea
- ✅ Considerar la complejidad técnica real
- ❌ No usar referencias temporales humanas ("2-3 días", "una semana")
- Enfoque: "Esto requiere modificar X archivos y crear Y componentes"

## Estilo de Comunicación

**Objetivo:** respuestas fáciles de leer, analizar y devolver (referenciando números).

**Contenido**
- ✅ Ir directo al punto; explicar solo lo necesario
- ✅ Una idea por bloque; evitar repetir la misma guía en varios formatos
- ❌ No duplicar pasos (“resumen”, “checklist” y “otra vez” con lo mismo)
- ❌ No explicaciones largas cuando basta un párrafo

**Pasos y pruebas (una sola lista por tema)**
- ✅ Una numeración `1. 2. 3.` por respuesta para lo que el usuario debe hacer
- ✅ Si hay plan B, darlo **después** de que pruebe la lista A (no mezclar dos flujos)
- ✅ Comandos de terminal: bloque copiable, **sin** comentarios `#` en la misma pegada
- ❌ Varios “camino A / camino B / opcional” en el mismo mensaje salvo que el usuario pida alternativas

**Preguntas al final**
- ✅ Toda pregunta al **cierre**, numerada: `1.` `2.` `3.`
- ✅ Formato devolución amigable: “1. sí, 2. no, 3. …” o citar el número + respuesta
- ✅ Agrupar preguntas en **un solo bloque** (no esparcirlas en el texto)
- ❌ Preguntas retóricas o muchos “¿querés que…?” al final de cada párrafo

**Estructura sugerida (cuando hay acción + seguimiento)**
1. Diagnóstico breve (1–3 oraciones)
2. Lista única de pasos o cambios hechos
3. Preguntas numeradas (si hace falta devolución)

**Sugerencias de mejora (opcional, no obligatorio cada turno)**
```
Listo. [Qué se hizo en una frase]

Sugerencia: [Mejora] — ¿la implementamos?
```

**Formato legacy (sugerencias puntuales):** igual que arriba; no usar si ya diste pasos numerados en el mismo mensaje.

## Prioridad: Experiencia de Usuario

**Priorizar UX cuando la tarea involucre interfaz**
- ✅ Flujos claros e intuitivos
- ✅ Feedback visual inmediato (loaders, toasts, estados de carga)
- ✅ Estados vacíos informativos con CTAs claras
- ✅ Diseño responsive cuando aplique
- ✅ Textos de acciones descriptivos y claros
- ⚠️ Antes de implementar UI, preguntar: "¿Esto mejora la experiencia del usuario?"

## Convenciones de Código

- Respetar convenciones existentes del repositorio (nombres, carpetas, estilo del código actual)
- No introducir dependencias ni patrones nuevos sin acordarlo con el usuario
- Tipado estricto cuando el proyecto use TypeScript
- Cambios acotados al alcance pedido; evitar refactors colaterales
- ❌ No crear archivos de documentación `.md` (README, CHANGELOG, etc.) salvo pedido explícito

## Reglas del repositorio (Cursor)

- `.cursor/rules/` **sí se versiona** (reglas compartidas del proyecto); no agregarlo a `.gitignore`
- Mantener `alwaysApply: true` en reglas que deban aplicar en todo el repo