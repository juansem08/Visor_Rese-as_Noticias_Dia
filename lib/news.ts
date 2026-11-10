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
