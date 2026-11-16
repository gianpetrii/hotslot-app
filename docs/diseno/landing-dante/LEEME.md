# Slots · Landing de preventa

Landing para validar interés mientras terminamos la app: muestra el producto, deja probarlo en vivo y junta una lista de espera. Diseño y copy: Dante. Para publicar: Gian.

Es **un solo archivo** (`index.html`) con todo adentro: estilos, scripts y textos en español e inglés. Lo único externo es la tipografía Inter Tight, que se carga desde Google Fonts. No necesita build ni dependencias.

```
slots-landing/
├── index.html    ← la página
├── favicon.svg   ← logo para la pestaña (también va embebido en el HTML)
└── LEEME.md      ← este archivo
```

---

## 1. Lo que hay que hacer para publicarla

### a) Conectar la lista de espera (obligatorio)

Hoy el formulario no manda los datos a ningún lado. Hay que pegar la dirección de un servicio de formularios en la línea que dice:

```js
const WAITLIST_ENDPOINT = "";
```

Está casi al principio del `<script>`, después del comentario `/* ===== Configuración ===== */`.

**Opción simple: Formspree** (tiene plan gratis con un tope mensual de envíos; revisar el límite actual antes de pautar)
1. Crear la cuenta en formspree.io con el mail donde queremos recibir los anotados.
2. Crear un formulario nuevo y copiar su dirección (`https://formspree.io/f/xxxxxxx`).
3. Pegarla en `WAITLIST_ENDPOINT`.

El formulario manda un `POST` con JSON (`Content-Type: application/json`, `Accept: application/json`) y toma como error cualquier respuesta que no sea 2xx. Sirve cualquier servicio que acepte eso: Formspree, Loops, Basin, un webhook de Make/Zapier o un Apps Script que escriba en una Google Sheet.

**Campos que llegan:**

| Campo | Ejemplo | Nota |
| --- | --- | --- |
| `email` | ana@mail.com | Obligatorio, se valida en el navegador |
| `equipo` | Mac · iPhone · Los dos | Siempre en español, aunque la persona use la página en inglés |
| `rol` | Diseño o creatividad, Freelance, Atención al cliente, Ventas, Estudio, Otro | Opcional, en español |
| `uso` | "mi alias de cobro y el link del portfolio" | Opcional, texto libre, máximo 500 caracteres |
| `idioma` | es · en | Idioma en que estaba la página al anotarse |
| `origen` | tiktok · reels · directo | Sale del `#` del link (ver punto 3) |
| `fecha` | 2026-11-02T14:05:00.000Z | ISO, hora UTC |

### b) Subirla a un dominio

Cualquier hosting estático sirve. Lo más rápido:
- **Vercel o Netlify:** arrastrar la carpeta `slots-landing` al panel (o `vercel deploy` desde la carpeta) y conectar el dominio.
- **GitHub Pages o Cloudflare Pages:** también sirven, porque es solo un `index.html`.

### c) Video de marca (opcional)

El bloque grande de arriba hoy es una animación hecha con código: el panel de vidrio y el aviso del notch. Para poner el video real:
1. Subir el mp4 junto al `index.html`. Conviene una versión liviana, sin sonido, en loop, de menos de 4 MB.
2. Completar `const VIDEO_SRC = "slots-loop.mp4";`

La página reemplaza la animación por el video en autoplay, mudo y en loop.

---

## 2. Qué tiene la página

1. **Arriba:** "Tu portapapeles, ahora con memoria.", campo de mail y la Mac animada.
2. **Probalo acá:** demo en vivo con un mail para escribir usando slots.
   - Compu: clic copia, ⌘V pega, arrastrar pega, ⇧ + A/S/D/Q/W pega directo.
   - Celular: tocar un slot lo pega en el mail. El mail no abre el teclado.
   - Si seleccionás texto y tocás el slot vacío, se guarda.
3. **Tres gestos:** Guardá / Pegá / Mirá todo, con un teclado que se ilumina y el notch que muestra Guardado, Pegado y los 5 slots desplegados. En el celular el notch recorre los tres estados solo.
4. **Tus atajos, tus reglas:** simulación de Ajustes › Atajos. Se elige una combinación y la página rechaza las que ya usa macOS (⌘Q, ⌘⇧Q, ⌘⌃Q, ⌘S, ⌘⌥D…), las repetidas dentro de Slots y las que no tienen ⌘ ni ⌃.
5. **iPhone:** un teléfono que se usa solo (un dedo toca cards y cambia de biblioteca). Si alguien lo toca, se pausa 8 segundos.
6. **Lo que trae:** las 6 funciones principales.
7. **Lista de espera:** formulario completo. El "Anotarme" de arriba y el del menú abren el mismo formulario en un pop-up.
8. **Preguntas** y cierre con "Copiá una vez. Pegá siempre."

**Controles del menú:**
- **ES / EN:** arranca en el idioma del navegador y recuerda la elección.
- **Día / noche:** arranca según el sistema y recuerda la elección.

**La página siempre abre arriba.** Los links del menú bajan con scroll, sin cambiar la URL, para que nadie comparta un link que abra en el medio.

---

## 3. Links por campaña

Agregando un `#` al final del link, cada anotado guarda de dónde vino:

```
slots.app/#tiktok
slots.app/#reels
slots.app/#ig-ads
slots.app/#ugc-martina
```

Ese valor llega en el campo `origen`. Sin `#` llega `directo`. Los nombres de sección (`#probalo`, `#lista`, etc.) no cuentan como origen.

---

## 4. Notas técnicas

- **Textos:** el español está en el HTML. El inglés está en el objeto `DICT` del script, con la frase en español como clave. **Si cambiás un texto en español, cambiá también su clave en `DICT`**, si no queda sin traducir. Los textos que arma el JavaScript (demo, iPhone, notch, atajos, mensajes del formulario) usan `L("español", "english")`.
- **Colores:** se definen como variables en `:root`, con un bloque para modo oscuro. Siguen los tokens de marca: Naranja #E2501D, Tinta #111111, Óxido #A8431A, Arena #E7DED2, Papel #F2F2F0.
- **Lista de atajos ocupados:** está en el objeto `SIS`, dentro del bloque "Atajos personalizables". Si cambian los atajos que vienen por defecto, revisar esa lista y el arreglo `base`.
- **`localStorage`:** guarda solo el idioma, el tema y el mail del último anotado (para precargarlo). Todo va dentro de try/catch, así que funciona igual sin él.
- **Animaciones:** respetan `prefers-reduced-motion`.
- **Código de Claude:** hay un bloque que usa `window.claude` para guardar la lista cuando la página está publicada dentro de Claude. Fuera de ahí no hace nada y se puede dejar como está. Si `WAITLIST_ENDPOINT` tiene valor, siempre se usa el endpoint.
- **Probada en:** Chrome desktop, iPhone 13, iPhone SE y Pixel 5 (emulados), en claro y oscuro, en español e inglés. Sin errores de consola y sin scroll horizontal.

---

## 5. Pendientes para decidir antes de difundirla

- [ ] **Promesas de la lista:** "precio de preventa", "acceso a la beta antes del lanzamiento" y "un mes gratis". Confirmar que las vamos a cumplir o ajustar el texto.
- [ ] **Atajos por defecto:** la página muestra ⌘⇧ + A/S/D/Q/W y ⌘⌃ + A/S/D/Q/W. ⌘⇧Q es cerrar sesión en macOS (está en la especificación como decisión abierta). Si cambian, actualizar la demo, "Tres gestos" y la lista `SIS`.
- [ ] **Privacidad:** la página dice "Sin cuenta y sin nube" y "no sube tus slots a ningún lado". Si Sync llega, conviene suavizarlo.
- [ ] **Imagen para compartir (og:image):** falta una imagen de 1200×630 para que el link se vea bien en WhatsApp e Instagram. Agregar `<meta property="og:image" content="https://…/og.png">` en el `<head>`.
- [ ] **Dominio** y **aviso de privacidad** (una línea con qué hacemos con los mails), si van a pautar.
- [ ] **Analytics** (opcional): Plausible o Vercel Analytics se agregan con una línea en el `<head>`.
