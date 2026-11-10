import { TEMAS, obtenerResumen, type Tema } from '@/lib/news';

export const dynamic = 'force-dynamic';
// 7 temas de uno en uno (con pausas) para no superar el límite por minuto de Gemini.
export const maxDuration = 300;

const PAUSA_MS = 6_000;

// Llamado cada mañana (ver vercel.json) para pedir a la IA el resumen de cada tema.
// Si CRON_SECRET está definido, exige "Authorization: Bearer <CRON_SECRET>"
// (Vercel Cron lo envía automáticamente).
export async function GET(request: Request) {
  const secreto = process.env.CRON_SECRET;
  if (secreto && request.headers.get('authorization') !== `Bearer ${secreto}`) {
    return new Response('No autorizado', { status: 401 });
  }

  const resultado: { tema: Tema; ok: boolean }[] = [];
  for (const tema of Object.keys(TEMAS) as Tema[]) {
    if (resultado.length > 0) await new Promise((r) => setTimeout(r, PAUSA_MS));
    try {
      const r = await obtenerResumen(tema, true);
      resultado.push({ tema, ok: r.origen === 'ia' });
    } catch {
      resultado.push({ tema, ok: false });
    }
  }
  return Response.json(resultado);
}
