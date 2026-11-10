import { normalizarTemas, obtenerResumenTemas } from '@/lib/news';

export const dynamic = 'force-dynamic';
// RSS + Gemini (con modelos de respaldo de hasta 25 s cada uno).
export const maxDuration = 90;

// GET /api/news?tema=deportes            -> 3 noticias de deportes
// GET /api/news?tema=mundo,deportes,salud -> 3 noticias repartidas entre esos temas
// Respuesta: { fecha, tema, noticias: [3 textos], categorias, origen }
// Es lo único que consume el reloj Garmin. Sin tema (o con temas inválidos) usa "mundo".
export async function GET(request: Request) {
  const valor = new URL(request.url).searchParams.get('tema');
  const resumen = await obtenerResumenTemas(normalizarTemas(valor));

  // En Vercel cada instancia tiene su propia memoria: la caché de la CDN evita
  // llamar a Gemini en cada petición. 30 min frescos y, mientras se regenera,
  // se sirve la versión anterior. Las respuestas de demostración no se guardan.
  const cache =
    resumen.origen === 'ia'
      ? 'public, s-maxage=1800, stale-while-revalidate=86400'
      : 'no-store';

  return Response.json(resumen, { headers: { 'Cache-Control': cache } });
}
