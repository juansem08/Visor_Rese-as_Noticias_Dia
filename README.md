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

