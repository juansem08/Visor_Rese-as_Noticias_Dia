import { obtenerResumen } from '@/lib/news';

export async function GET(request: Request) {
  const resumen = await obtenerResumen('mundo');
  return Response.json(resumen);
}
