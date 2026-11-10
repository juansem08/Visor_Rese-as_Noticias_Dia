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
