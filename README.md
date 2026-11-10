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

