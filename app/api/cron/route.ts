import { TEMAS, obtenerResumen, type Tema } from '@/lib/news';

export async function GET(request: Request) {
  const resultado: { tema: Tema; ok: boolean }[] = [];
  for (const tema of Object.keys(TEMAS) as Tema[]) {
    try {
      const r = await obtenerResumen(tema, true);
      resultado.push({ tema, ok: r.origen === 'ia' });
    } catch {
      resultado.push({ tema, ok: false });
    }
  }
  return Response.json(resultado);
}
