import { esTema, obtenerResumen } from '@/lib/news';

// GET /api/news?tema=deportes -> { fecha, tema, noticias: [3 textos], categorias, origen }
// Es lo único que consume el reloj Garmin. Sin tema (o con uno inválido) usa "mundo".
export async function GET(request: Request) {
  const valor = new URL(request.url).searchParams.get('tema');
  const resumen = await obtenerResumen(esTema(valor) ? valor : 'mundo');
  return Response.json(resumen);
}
