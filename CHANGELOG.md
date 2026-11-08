# Changelog

## [1.0.0] — 2026-11-08

La primera versión completa de Slots.

### Notch

- Se puede arrastrar un archivo hacia el notch: la barra se abre sola y lo soltás sobre un slot.
- En Ajustes hay un interruptor para desactivar la barra del notch.

### Privacidad

- Uso anónimo opcional, apagado por defecto. Se ofrece en el onboarding (y una sola vez a quienes ya lo completaron) y se cambia en Ajustes → General → Privacidad. Solo cuenta qué funciones se usan: nunca lo que copiás, nombres de archivos, bibliotecas o slots, ni quién sos.

### Actualizaciones

- Si hay una versión nueva mientras trabajás, aparece un aviso en el notch y una línea «Actualización disponible» arriba del menú del ícono.

### Ajustes

- Se quitó la pestaña «Slots» y la sección de depuración. Los textos ya no dicen «⌘» donde va el ícono de la app.

### Historial

- Al pasar el mouse, la sombra de la fila ya no se corta a los costados ni se ve en las letras: la fila pasa a papel opaco, como las cards de los slots.

### Licencia

- La prueba gratuita pasa de 90 a 30 días. Quien instaló hace más de 30 días y no tiene licencia queda con el slot 1 al actualizar.

### Interno

- Los slots viven en un solo lugar. Al abrir por primera vez se hace una copia de seguridad en `Application Support/HotSlot/Backups/`.

## [0.24.0] — 2026-11-07

### Barra del notch

- Al pasar el mouse por el notch (o por el centro de la barra de menú en Macs sin notch) baja una barra con los 5 slots y las bibliotecas, con el mismo estilo del panel.
- Un clic en un slot con contenido copia o pega según Ajustes. En un slot vacío guarda el portapapeles. Cada slot muestra su atajo.
- Un botón redondo abre el panel completo. La barra se cierra sola tras cualquier clic y no se abre con el panel, Ajustes o el onboarding visibles.

### Archivos

- Los archivos y carpetas se pueden guardar en slots y aparecen en el historial. Se guarda una referencia (no una copia) y se sigue el archivo si se renombra o se mueve.
- Copiar un archivo en Finder lo guarda como archivo, no como su nombre. También se puede soltar uno sobre un slot del panel.
- Un archivo por slot. Si ya no está en su lugar, el slot lo avisa y el portapapeles no se toca.

### Panel

- Hover unificado: sombra más marcada y un leve agrandado en slots, bibliotecas y botones. Las filas del historial solo cambian la sombra.

## [0.23.0] — 2026-11-07

### Panel

- El clic en un slot o en el historial copia al portapapeles. En Ajustes se puede volver a pegar donde estaba el cursor. Los atajos siguen pegando.
- Al hacer clic, el slot se llena de su color un instante antes de cerrar. En el historial solo cambia el fondo a papel y el texto sigue visible.
- Hover unificado: la misma sombra en slots con contenido, historial, bibliotecas y «+». El «+» hace un pulso al crear una biblioteca.
- El fondo predeterminado de un slot con contenido es papel. Vaciarlo muestra el estilo vacío, recuerda el color y lo restaura al guardar, con una transición.
- El aviso del notch sigue negro al copiar, guardar o pegar. Pasa a naranja cuando pide una acción (slot vacío o permiso de Accesibilidad).

## [0.22.1] — 2026-11-05

### Slots

- La cruz y el atajo usan la misma pastilla: arena en cards claras, blanca sobre imagen o fondo oscuro. Ya no desaparece el fondo del atajo al pasar el mouse.
- Al aparecer la cruz, «Slot N» se corre a la derecha en vez de quedar debajo.

## [0.22.0] — 2026-11-05

### Historial

- El texto conserva los saltos de línea. Cerrado muestra 2 renglones; al pasar el mouse, hasta 8, y solo si algo quedó cortado.
- Pin arriba a la derecha, solo el ícono (fondo blanco únicamente sobre la imagen agrandada). Fijado: contorno naranja.

### Pegado

- Al pegar desde el historial o un slot se conserva el formato original (negrita y demás) cuando la app de destino lo acepta; si no, texto plano.

## [0.21.0] — 2026-11-05

### Accesibilidad

- Vuelve el aviso del sistema para pedir Accesibilidad (onboarding y Ajustes → Permisos). La causa era App Sandbox, que bloquea el aviso; la app se distribuye sin sandbox (DMG Developer ID notarizado).
- El aviso se trae al frente: antes quedaba tapado por las ventanas flotantes de Slots. Ajustes del Sistema solo se abre si el aviso no aparece.
- Ya no se pide permiso de Automatización.
- Migración única de historial, slots, imágenes y preferencias desde el contenedor del sandbox.

### Bibliotecas

- Arrastre propio para reordenar: las pills se separan, queda un fantasma en el lugar de origen y la pill vuela a su posición al soltar.
- Tacho estilo Instagram al arrastrar; eliminar con confirmación y opción «No volver a preguntar» (también en Ajustes).
- Animación al cambiar de biblioteca.
- Botón principal naranja en todos los avisos de la app.

## [0.20.1] — 2026-11-03

### Panel (revisión UX — probar antes de dar por cerrado)

- Bibliotecas: reorden con marca de inserción; tacho fijo visible; renombrar en menú contextual; drag de biblioteca separado del de slots.
- Slot/historial ya no actúan al soltar en pills del footer (solo slots o menú «Mover a…»).
- Historial/slots: hovers con borde en lugar de sombras recortadas; menos clip agresivo en el panel.

### Docs

- `DECISIONES-UX-PANEL.md` y checklist en estado **en revisión**.

## [0.20.0] — 2026-11-03

### Panel UX (handoff + mejoras Gianluca)

- Historial: pin al hover (sin fondo); peek de imagen y expansión de texto largo.
- Slots: título abajo, renombrar inline, cruz vaciar a la izquierda, contenido real en card, imagen recortada al marco.
- Atajos: chip contextual guardar/pegar; popover compacto de grabación.
- Bibliotecas: reorden por drag, tacho al arrastrar, eliminar con confirmación; fondos de slot (handoff + degradé naranja).
- Apertura del panel más rápida; cabecera alineada; modales overlay (eliminar biblioteca).

### Otros

- Notch aviso en AppKit; menú barra y TCC dev (copiar a Aplicaciones); guía `docs/PRUEBA-MAC-REDISENO.md` y `docs/DECISIONES-UX-PANEL.md`.

## [0.19.0] — 2026-11-02

### Rediseño macOS (handoff Dante)

- Panel principal alineado a `Main`: grilla 3×2, cabecera, historial, footer, vidrio y tokens Inter Tight.
- Icono de menú desde marca Slots; fixture «Cargar ejemplo» coherente con el mock.
- Modales del panel vía overlay (nueva biblioteca y elegir slot al guardar); corrige `.sheet` que no abría en `NSPanel`.

### Docs

- `docs/DESVIOS-DISENO-DANTE.md` para validación con diseño.

## [0.18.4] — 2026-11-01

### UX

- Panel se cierra al abrir Ajustes/Licencia; misma posición diagonal; vuelve al cerrar Ajustes.
- Ajustes flotante sin ocultarse al usar otra app o la barra de menú; barra de menú no cierra el panel con Ajustes abiertos.
- Fondo del panel ignora clics en la barra de menú; scroll a Licencia sin mover la ventana.

### Accesibilidad

- TCC: `kCFBooleanTrue`, ventana principal, reintento de posición; diagnóstico en Permisos.

## [0.18.3] — 2026-11-01

### UX

- Ajustes en ventana normal (no flota sobre otras apps); scroll a Licencia desde el panel.
- Accesibilidad: activación más fiable antes del aviso TCC (ventana clave + `.regular`).

## [0.18.2] — 2026-11-01

### UX

- Onboarding centrado, fondo no bloqueante, se oculta al cambiar de app.
- Accesibilidad unificada (onboarding + Ajustes); menú barra: Licencia / Comprar; panel ⋯ Salir.
- Semilla del clip actual al instalar; guía barra de menú.

### Producto

- Activación de licencia **Lemon Squeezy** (UUID); checkout en `purchase.html`.

## [0.18.1] — 2026-10-26

### UX

- Al pegar sin Accesibilidad: **diálogo nativo del sistema** primero (sin abrir Ajustes automáticamente).
- Aviso único si el ⌘ no cabe en la barra de menú; `autosaveName` en el ítem.

### Producto (base)

- **Trial 90 días** desde primera instalación; después solo **slot 1** sin licencia.
- Activación de clave en Ajustes; `docs/purchase.html` y `docs/MONETIZATION.md`.
- Script de release: `release.env.local`, perfil `notarytool` en Llavero.

## [0.18.0] — 2026-10-25

### Marca y UX

- Nombre visible **Slots** (Finder, UI, web). Bundle ID interno sin cambios (`com.hotslot.app`).
- Icono **⌘** gris / vidrio en Dock; barra de menú con SF Symbol template.
- Landing **Slots** (descarga `Slots-0.18.0.dmg`, favicon, copy slots-first).
- Atajo del panel editable desde el **badge en la barra de búsqueda** (y en Ajustes → Atajos).
- Dos badges por slot (pegar + guardar); ancho fijo para que el popover no salte al grabar.

### Correcciones

- **Esc** cierra el panel con la misma animación que clic fuera.
- Atajos globales estables tras grabar (`onKeyUp` + `reloadFromStorage` sin carreras).
- Doble clic en **Aplicaciones** o reabrir la app muestra el panel (app de barra de menú).
- Acento de UI gris (ya no azul del icono viejo).
- Accesibilidad: enlace a Ajustes del Sistema más fiable.

## [0.17.0] — 2026-10-25

### Mejoras

- Un solo flujo de **Ajustes** (sin ventana duplicada de SwiftUI); ventana por encima del panel.
- Al cerrar Ajustes, el panel **solo se reabre** si estaba abierto antes.
- **Atajos desde el panel:** clic en el badge del slot → editar pegar/guardar.
- Atajos aplicados al vuelo al grabarlos (sin relanzar la app).
- **Menu bar:** icono `clipboard.fill` más visible.
- **Sparkle** integrado (menú “Buscar actualizaciones…”); appcast y clave pública pendientes en el primer release con updates.

## [0.16.0] — 2026-10-08

### Distribución directa (fuera de Mac App Store)

- Pegado automático restaurado con **Accesibilidad + CGEvent** (comportamiento validado en v0.15.0).
- Mejor detección de app destino al abrir el panel (`captureForUpcomingPaste`).
- Panel no roba foco al abrirse (`orderFrontRegardless`).
- Documentación de release: `docs/DIRECT_DOWNLOAD.md`, script `scripts/release-direct.sh`.

### Removido

- Experimento v0.15.1 (System Events / Automatización sin Accesibilidad) — no cumplía la UX esperada.

## [0.15.0] — 2026-10

- Onboarding, sandbox, preparación App Store (build rechazado por Accesibilidad en revisión).

## Versiones anteriores

Ver tabla en [README.md](README.md).
