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
