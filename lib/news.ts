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

// Caché en memoria: una generación por tema y por día. La primera petición del día
// (o el cron de la mañana) llama a la IA; el resto reutiliza el resultado.
const cache = new Map<Tema, ResumenDelDia>();
const enCurso = new Map<Tema, Promise<ResumenDelDia>>();

export function esTema(valor: string | null | undefined): valor is Tema {
  return !!valor && Object.prototype.hasOwnProperty.call(TEMAS, valor);
}

/**
 * "deportes,mundo,xyz" -> ['mundo', 'deportes'] (válidos, sin repetir y en el orden de TEMAS).
 * Sin ninguno válido devuelve ['mundo'].
 */
export function normalizarTemas(valor: string | null | undefined): Tema[] {
  const pedidos = new Set((valor ?? '').split(',').map((t) => t.trim().toLowerCase()));
  const temas = (Object.keys(TEMAS) as Tema[]).filter((t) => pedidos.has(t));
  return temas.length > 0 ? temas : ['mundo'];
}

/** Respuesta para el reloj: un tema o una mezcla ("mundo,deportes"). */
export type RespuestaNoticias = Omit<ResumenDelDia, 'tema'> & { tema: string };

/**
 * Las 3 noticias repartidas entre varios temas. Se usan como máximo 3 temas por día
 * (rotando cuáles según la fecha si el usuario eligió más), y cada tema reutiliza su
 * resumen diario en caché, así que mezclar no gasta llamadas extra a Gemini.
 */
export async function obtenerResumenTemas(temas: Tema[]): Promise<RespuestaNoticias> {
  const clave = temas.join(',');
  if (temas.length === 1) return { ...(await obtenerResumen(temas[0])), tema: clave };

  const hoy = fechaHoy();
  const dia = Math.floor(Date.parse(hoy) / 86_400_000);
  const inicio = dia % temas.length;
  const elegidos = Array.from({ length: Math.min(3, temas.length) }, (_, i) => temas[(inicio + i) % temas.length]);

  // De uno en uno para no superar el límite por minuto de Gemini si alguno no está en caché.
  const resumenes: ResumenDelDia[] = [];
  for (const t of elegidos) resumenes.push(await obtenerResumen(t));

  // Reparto: tema A, tema B, tema C (o A, B, A si solo hay dos).
  const noticias: string[] = [];
  const categorias: string[] = [];
  for (let i = 0; i < 3; i++) {
    const r = resumenes[i % resumenes.length];
    const n = Math.floor(i / resumenes.length);
    noticias.push(r.noticias[n]);
    categorias.push(r.categorias[n]);
  }

  return {
    fecha: hoy,
    tema: clave,
    noticias: noticias as [string, string, string],
    categorias: categorias as [string, string, string],
    origen: resumenes.every((r) => r.origen === 'ia') ? 'ia' : 'demo',
  };
}

export function fechaHoy(): string {
  // en-CA produce el formato YYYY-MM-DD
  return new Intl.DateTimeFormat('en-CA', { timeZone: ZONA_HORARIA }).format(new Date());
}

export async function obtenerResumen(tema: Tema = 'mundo', forzar = false): Promise<ResumenDelDia> {
  const hoy = fechaHoy();
  const guardado = cache.get(tema);
  if (!forzar && guardado?.fecha === hoy) return guardado;

  const pendiente = enCurso.get(tema);
  if (pendiente) return pendiente;

  const promesa = generarResumen(tema, hoy)
    .then((r) => {
      // Solo se guarda en caché si viene de la IA; el modo demo se reintenta.
      if (r.origen === 'ia') {
        cache.set(tema, r);
        return r;
      }
      // Si la IA falló (cuota, saturación), mejor el último resumen real que el demo.
      return guardado ?? r;
    })
    .finally(() => enCurso.delete(tema));
  enCurso.set(tema, promesa);
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

/** Etiqueta para la píldora del reloj: mayúsculas, máx. 2 palabras y 16 caracteres. */
function limpiarCategoria(valor: string): string {
  const palabras = valor
    .replace(/^\s*(\d+[.)]|[-*•])\s*/, '')
    .replace(/[*_`#"“”]/g, '')
    .trim()
    .toUpperCase()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2);
  // Corta por palabras completas: "INTELIGENCIA ARTIFICIAL" -> "INTELIGENCIA", nunca "INTELIGENCIA ART".
  const dos = palabras.join(' ');
  if (dos.length <= 16) return dos;
  return (palabras[0] ?? '').slice(0, 16);
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
