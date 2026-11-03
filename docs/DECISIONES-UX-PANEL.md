# Decisiones UX — panel macOS (Gianluca + socio)

Alineado a tokens `SlotsTheme` / handoff `Main.html`. Estado: **nov 2026 — revisión activa** (no dar por validado hasta pasada completa).

## Resumen de acuerdos

| Tema | Decisión | Estado |
|------|----------|--------|
| Flecha historial | Quitar; **pin** solo al **hover** (sin fondo) | En revisión |
| Atajos en slot | **Vacío → guardar** · **Con contenido → pegar** · popover compacto | En revisión |
| Contenido en slot | Texto/link en cuerpo; imagen **contenida** | En revisión |
| Cruz vaciar | Izquierda; «Slot N» se corre al hover | En revisión |
| Renombrar slot | Inline abajo; Enter / clic en card / Esc | En revisión |
| Bibliotecas | Reorden (marca de inserción + escala) · **Tacho fijo** · Renombrar (menú) | En revisión |
| Slot → otra biblioteca | Solo **menú «Mover a…»** o drop en slot tras cambiar pill; **no** auto-cambio al hover | Implementado (nov) |
| Fondos de slot | Default handoff; degradé naranja opcional | En revisión |
| Tamaño / forma de slots | Grilla editable (Epic B) | Pendiente |

---

## Epic A — En revisión (checklist `PRUEBA-MAC-REDISENO.md`)

### A4 Bibliotecas (último ajuste)
- **Reorden:** barra naranja de inserción + pill objetivo escala ~1,03; la arrastrada semitransparente (sin correr todas las pills).
- **Eliminar:** tacho **siempre visible** junto al scroll (no adentro); se ilumina al arrastrar una biblioteca encima.
- **Renombrar:** clic derecho en la pill (sin `Button` que oculte ítems) → modal.
- **Drag slot/historial:** las pills **no** aceptan ese drop; soltar en footer no mueve contenido (cancelación implícita).

---

## Epic B — Pendiente

### B1 Tamaños de slot en grilla
### B2 Más paleta / fondos
### B3 Copy al eliminar biblioteca (handoff)

---

## Referencias

- Desvíos visuales: `docs/DESVIOS-DISENO-DANTE.md`
- Backlog operativo: `BACKLOG.md` › Panel UX
