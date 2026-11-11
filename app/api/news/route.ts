import { fechaHoy, normalizarTemas, obtenerResumenTemas } from '@/lib/news';

export const dynamic = 'force-dynamic';
// RSS + Gemini (con modelos de respaldo de hasta 25 s cada uno).
export const maxDuration = 90;

// GET /api/news?tema=deportes            -> 3 noticias de deportes
// GET /api/news?tema=mundo,deportes,salud -> 3 noticias repartidas entre esos temas
// El reloj añade &dia=YYYY-MM-DD: cada día es una URL distinta, así la CDN nunca
// le entrega el resumen de ayer a la hora del aviso.
// Respuesta: { fecha, tema, noticias: [3 textos], categorias, origen }
export async function GET(request: Request) {
  const valor = new URL(request.url).searchParams.get('tema');
  const resumen = await obtenerResumenTemas(normalizarTemas(valor));

  // Caché en la CDN de Vercel solo para resúmenes reales de HOY. Como el reloj pide una
  // URL distinta cada día (&dia=), se puede guardar 6 h sin riesgo de servir el de ayer,
  // y así casi no se llama a Gemini (la cuota gratuita es limitada).
  // Si es demo o un resumen de otro día (respaldo cuando la IA falla), no se guarda.
  const deHoy = resumen.fecha === fechaHoy();
  const cache =
    resumen.origen === 'ia' && deHoy
      ? 'public, s-maxage=21600, stale-while-revalidate=600'
      : 'no-store';

  return Response.json(resumen, { headers: { 'Cache-Control': cache } });
}
