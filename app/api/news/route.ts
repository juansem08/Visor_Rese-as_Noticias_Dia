import { esTema, obtenerResumen } from '@/lib/news';

// GET /api/news?tema=deportes -> { fecha, tema, noticias: [3 textos], categorias, origen }
// Es lo único que consume el reloj Garmin. Sin tema (o con uno inválido) usa "mundo".
export async function GET(request: Request) {
  const valor = new URL(request.url).searchParams.get('tema');
  const resumen = await obtenerResumen(esTema(valor) ? valor : 'mundo');

  // En Vercel cada instancia tiene su propia memoria: la caché de la CDN evita
  // llamar a Gemini en cada petición. 30 min frescos y, mientras se regenera,
  // se sirve la versión anterior. Las respuestas de demostración no se guardan.
  const cache =
    resumen.origen === 'ia'
      ? 'public, s-maxage=1800, stale-while-revalidate=86400'
      : 'no-store';

  return Response.json(resumen, { headers: { 'Cache-Control': cache } });
}
