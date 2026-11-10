import { GoogleGenAI } from '@google/genai';

/** Temas disponibles. El orden debe coincidir con la lista de ajustes del reloj (garmin/resources). */
export const TEMAS = {
  mundo: 'noticias globales generales (política internacional, sociedad, sucesos)',
  tecnologia: 'tecnología e inteligencia artificial',
  deportes: 'deportes',
  economia: 'economía, mercados y negocios',
  ciencia: 'ciencia y espacio',
  salud: 'salud y medicina',
  cultura: 'cultura, cine, música y entretenimiento',
} as const;

export type Tema = keyof typeof TEMAS;

/** Etiqueta por defecto de cada tema (si la IA no da una categoría). */
const ETIQUETAS: Record<Tema, string> = {
  mundo: 'MUNDO',
  tecnologia: 'TECNOLOGÍA',
  deportes: 'DEPORTES',
  economia: 'ECONOMÍA',
  ciencia: 'CIENCIA',
  salud: 'SALUD',
  cultura: 'CULTURA',
};

export type ResumenDelDia = {
  fecha: string; // YYYY-MM-DD en la zona horaria configurada
  tema: Tema;
  noticias: [string, string, string];
  categorias: [string, string, string]; // etiqueta corta de cada noticia (p. ej. "ECONOMÍA")
  origen: 'ia' | 'demo';
};

const MAX_PALABRAS = 15;
const ZONA_HORARIA = process.env.NEWS_TIMEZONE ?? 'America/Bogota';
const MODELO = process.env.GEMINI_MODEL ?? 'gemini-3.8-flash';

export function fechaHoy(): string {
  // en-CA produce el formato YYYY-MM-DD
  return new Intl.DateTimeFormat('en-CA', { timeZone: ZONA_HORARIA }).format(new Date());
}

export function esTema(valor: string | null | undefined): valor is Tema {
  return !!valor && Object.prototype.hasOwnProperty.call(TEMAS, valor);
}

function demo(tema: Tema, fecha: string): ResumenDelDia {
  return {
    fecha,
    tema,
    origen: 'demo',
    noticias: [
      'Modo demo: configura GEMINI_API_KEY en el backend para ver noticias reales.',
      'Cada mañana el servidor pide a la IA tres noticias globales resumidas.',
      'Desliza arriba o abajo, o usa los botones, para leer cada noticia.',
    ],
    categorias: ['CONFIGURACIÓN', 'CÓMO FUNCIONA', 'CONTROLES'],
  };
}

/**
 * Quita numeración, viñetas, markdown y citas, normaliza caracteres que las
 * fuentes del reloj no tienen (comillas tipográficas, rayas, “…”) y recorta a 15 palabras.
 */
function limpiar(linea: string): string {
  const texto = linea
    .replace(/^\s*(\d+[.)]|[-*•])\s*/, '')
    .replace(/[*_`#]/g, '')
    .replace(/\[\d+(,\s*\d+)*\]/g, '')
    .replace(/[“”«»]/g, '"')
    .replace(/[‘’]/g, "'")
    .replace(/[–—]/g, '-')
    .replace(/…/g, '...')
    .replace(/\s+/g, ' ')
    .trim();
  const palabras = texto.split(' ').filter(Boolean);
  if (palabras.length <= MAX_PALABRAS) return palabras.join(' ');
  return palabras.slice(0, MAX_PALABRAS).join(' ').replace(/[,;:.]$/, '') + '...';
}

/** Etiqueta para la píldora del reloj: mayúsculas, máx. 2 palabras y 16 caracteres. */
function limpiarCategoria(valor: string): string {
  return valor
    .replace(/^\s*(\d+[.)]|[-*•])\s*/, '')
    .replace(/[*_`#"“”]/g, '')
    .trim()
    .toUpperCase()
    .split(/\s+/)
    .slice(0, 2)
    .join(' ')
    .slice(0, 16)
    .trim();
}

/** Sección de Google Noticias de cada tema. */
const SECCIONES_RSS: Record<Tema, string> = {
  mundo: 'WORLD',
  tecnologia: 'TECHNOLOGY',
  deportes: 'SPORTS',
  economia: 'BUSINESS',
  ciencia: 'SCIENCE',
  salud: 'HEALTH',
  cultura: 'ENTERTAINMENT',
};

// Edición de Google Noticias (país). Español latinoamericano; Colombia por defecto.
const PAIS_RSS = process.env.NEWS_COUNTRY ?? 'CO';

/** Hasta 20 titulares de hoy de Google Noticias para el tema. */
async function obtenerTitulares(tema: Tema): Promise<string[]> {
  const url =
    `https://news.google.com/rss/headlines/section/topic/${SECCIONES_RSS[tema]}` +
    `?hl=es-419&gl=${PAIS_RSS}&ceid=${PAIS_RSS}:es-419`;
  const res = await fetch(url, { cache: 'no-store', signal: AbortSignal.timeout(10_000) });
  if (!res.ok) throw new Error(`RSS ${res.status}`);
  const xml = await res.text();

  const titulares: string[] = [];
  for (const item of xml.matchAll(/<item>([\s\S]*?)<\/item>/g)) {
    const titulo = item[1].match(/<title>([\s\S]*?)<\/title>/)?.[1];
    if (titulo) titulares.push(decodificar(titulo));
    if (titulares.length >= 20) break;
  }
  return titulares;
}

function decodificar(texto: string): string {
  return texto
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&amp;/g, '&')
    .trim();
}

// Si el modelo principal está saturado (503), sin cuota (429) o tarda demasiado, se prueba el siguiente.
const MODELOS = [...new Set([MODELO, 'gemini-3.5-flash', 'gemini-flash-lite-latest'])];
const LIMITE_MS = 25_000;

async function pedirAGemini(ai: GoogleGenAI, prompt: string, conBusqueda: boolean) {
  let ultimoError: unknown;
  for (const model of MODELOS) {
    try {
      return await ai.models.generateContent({
        model,
        contents: prompt,
        config: {
          temperature: 0.3,
          abortSignal: AbortSignal.timeout(LIMITE_MS),
          ...(conBusqueda ? { tools: [{ googleSearch: {} }] } : {}),
        },
      });
    } catch (err) {
      console.warn(`Gemini "${model}" falló, probando el siguiente modelo:`, (err as Error).message?.slice(0, 160));
      ultimoError = err;
    }
  }
  throw ultimoError;
}

// Caché en memoria: una generación por tema y por día. La primera petición del día
// (o el cron de la mañana) llama a la IA; el resto reutiliza el resultado.
const cache = new Map<Tema, ResumenDelDia>();

export async function obtenerResumen(tema: Tema = 'mundo', forzar = false): Promise<ResumenDelDia> {
  const hoy = fechaHoy();
  const guardado = cache.get(tema);
  if (!forzar && guardado?.fecha === hoy) return guardado;

  const promesa = generarResumen(tema, hoy).then((r) => {
    if (r.origen === 'ia') {
      cache.set(tema, r);
    }
    return r;
  });
  return promesa;
}

async function generarResumen(tema: Tema, fecha: string): Promise<ResumenDelDia> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.warn('GEMINI_API_KEY no configurada: se devuelven noticias de demostración.');
    return demo(tema, fecha);
  }

  const formato = [
    `Resume cada una en español en MÁXIMO ${MAX_PALABRAS} palabras, en una sola frase clara.`,
    'Responde SOLO con 3 líneas con el formato: CATEGORÍA | resumen',
    'La categoría es 1 o 2 palabras en mayúsculas (ej.: ECONOMÍA, FÚTBOL, CLIMA, ELECCIONES).',
    'Sin numeración, sin viñetas, sin markdown, sin fuentes ni enlaces.',
  ];

  try {
    // 1) Titulares reales de hoy desde Google Noticias (gratis, sin clave).
    // 2) Gemini solo elige y resume: no necesita la búsqueda de Google (que no tiene cuota gratuita).
    // Si el RSS falla, se intenta con la búsqueda de Google integrada en Gemini.
    const titulares = await obtenerTitulares(tema).catch((err) => {
      console.warn(`No se pudo leer el RSS de "${tema}":`, err);
      return [] as string[];
    });

    const prompt =
      titulares.length >= 3
        ? [
            `Hoy es ${fecha}. Estos son titulares reales de hoy sobre ${TEMAS[tema]}:`,
            ...titulares.map((t) => `- ${t}`),
            '',
            'Elige las 3 noticias más importantes y distintas entre sí, priorizando las de alcance global.',
            'Usa SOLO la información de los titulares; no inventes datos.',
            ...formato,
          ].join('\n')
        : [
            `Hoy es ${fecha}. Busca las 3 noticias más importantes a nivel global de las últimas 24 horas sobre: ${TEMAS[tema]}.`,
            ...formato,
          ].join('\n');

    const res = await pedirAGemini(new GoogleGenAI({ apiKey }), prompt, titulares.length < 3);

    const items = (res.text ?? '')
      .split('\n')
      .map((linea) => {
        const corte = linea.indexOf('|');
        const categoria = corte >= 0 ? limpiarCategoria(linea.slice(0, corte)) : '';
        const texto = limpiar(corte >= 0 ? linea.slice(corte + 1) : linea);
        return { categoria: categoria || ETIQUETAS[tema], texto };
      })
      .filter((i) => i.texto.length > 0)
      .slice(0, 3);

    if (items.length < 3) throw new Error(`Respuesta incompleta de la IA: ${res.text}`);
    return {
      fecha,
      tema,
      noticias: items.map((i) => i.texto) as [string, string, string],
      categorias: items.map((i) => i.categoria) as [string, string, string],
      origen: 'ia',
    };
  } catch (err) {
    console.error(`Error generando el resumen de "${tema}" con la IA:`, err);
    return demo(tema, fecha);
  }
}
