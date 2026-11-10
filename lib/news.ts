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
