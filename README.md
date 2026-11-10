# Visor de Resúmenes de Noticias del Día – Garmin Forerunner 165

Cada mañana un backend sencillo pide a la IA (Gemini con búsqueda de Google) las
**3 noticias globales del día, en máximo 15 palabras cada una**. El reloj solo
muestra un **carrusel vertical** para leerlas.

```
Forerunner 165 ──BLE──> app Garmin Connect (móvil) ──HTTPS──> /api/news ──> Gemini
```

## Estructura

| Ruta | Qué hace |
|---|---|
| `lib/news.ts` | Pide las noticias a la IA por tema, limpia el texto, recorta a 15 palabras y guarda en caché una vez por tema y día. |
| `app/api/news/route.ts` | `GET /api/news?tema=deportes` que consume el reloj: `{ "fecha", "tema", "noticias": ["…","…","…"], "origen" }` |
| `app/api/cron/route.ts` | Lo llama el cron de la mañana (`vercel.json`, 11:00 UTC = 6:00 Bogotá) para generar el resumen de todos los temas. |
| `app/page.tsx` | Página de verificación con las mismas 3 noticias y selector de tema. |
| `garmin/` | App Connect IQ (Monkey C) para el Forerunner 165 / 165 Music. |

Temas: `mundo` (por defecto), `tecnologia`, `deportes`, `economia`, `ciencia`, `salud`, `cultura`.

## Ajustes desde el teléfono

En la app **Garmin Connect** → Dispositivo → Apps Connect IQ → *Noticias del Dia* → Ajustes:

| Ajuste | Qué hace |
|---|---|
| Tema de las noticias | Cambia el tema de las 3 noticias (si la app está abierta, se actualiza al momento). |
| Aviso diario en el reloj | Activa o desactiva el aviso de la mañana. |
| Hora del aviso (0-23) y minuto | Hora a la que el reloj descarga las noticias en segundo plano, vibra y pregunta si quieres abrir la app. |

> Connect IQ no permite notificaciones push libres: el aviso es el mensaje del sistema
> "¿Abrir Noticias del Dia?". El aviso queda programado después de abrir la app una vez;
> si cambias la hora con la app cerrada, se aplica la próxima vez que la abras o tras el siguiente aviso.


## 2. App del reloj (`garmin/`)

Requisitos: [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) con el
dispositivo **Forerunner 165** descargado en el SDK Manager, y la extensión
*Monkey C* de VS Code.

1. Edita `BACKEND_URL` en `garmin/source/Config.mc` con tu URL `https://…/api/news`.
2. En VS Code: `Monkey C: Generate a Developer Key` (solo la primera vez).
3. Abre la carpeta `garmin/` y ejecuta `Monkey C: Run App` → elige `fr165`.
   - Ajustes en el simulador: *File → Edit Persistent Storage → Edit Application.Properties*.
   - Aviso en el simulador: *Simulation → Background Events → Temporal Event*.
   - Para probar con el backend local en el simulador usa
     `http://localhost:3000/api/news` y desmarca
     *Settings → Use Device HTTPS Requirements*.
4. Para instalar en el reloj: `Monkey C: Build for Device` → `fr165` y copia el
   `.prg` a `GARMIN/APPS/` del reloj conectado por USB.

Desde la línea de comandos:

```bash
monkeyc -f garmin/monkey.jungle -d fr165 -o garmin/bin/NoticiasDelDia.prg -y developer_key.der
```

### Uso en el reloj

Flujo: **Portada** ("Noticias del día") → **01/03** → **02/03** → **03/03** → **Estás al día**.
Sin noticias guardadas se ve **Preparando tu resumen** o **Sin conexión**.

| Gesto / botón | Acción |
|---|---|
| Deslizar arriba · botón DOWN | Siguiente (portada → noticias → "Estás al día") |
| Deslizar abajo · botón UP | Anterior |
| START | Leer (portada) · actualizar (noticia) · reintentar (sin conexión) · volver a empezar ("Estás al día") |
| Toque | Pulsa el botón visible: LEER RESUMEN o REINTENTAR |
| BACK | Salir |

El estilo sigue la guía de diseño: negro puro, acento lima `0xC8FF2E`, morado `0xB794FF`
para "actualizando", naranja `0xFF9F43` para "sin conexión", anillo de 3 arcos de 116°
(radio 184, grosor 8) que se llena un tercio por noticia y arco START en 22°–38°.
Todo está en `garmin/source/Ui.mc`.

### Tipografía
La app incluye sus propias fuentes en `garmin/resources/fonts/` (formato BMFont):
**Barlow Condensed Bold** para títulos y números, e **Inter** para titulares, etiquetas y textos
(ambas con licencia SIL OFL, de Google Fonts). Para regenerarlas (por ejemplo, otro tamaño):

```bash
pip install pillow
# descarga BarlowCondensed-Bold.ttf e Inter[opsz,wght].ttf (renombrado a Inter.ttf) en una carpeta
python garmin/tools/genfonts.py <carpeta_ttf> garmin/resources/fonts
```

Las últimas noticias se guardan en el reloj, así que se ven aunque el teléfono no
esté conectado.
