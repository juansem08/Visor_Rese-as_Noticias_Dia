import { esTema, obtenerResumen } from '@/lib/news';

export const dynamic = 'force-dynamic';

// Página de verificación: muestra lo mismo que recibirá el reloj para cada tema.
export default async function Home({ searchParams }: { searchParams: Promise<{ tema?: string }> }) {
  const { tema: valor } = await searchParams;
  const tema = esTema(valor) ? valor : 'mundo';
  const { fecha, noticias, categorias, origen } = await obtenerResumen(tema);

  return (
    <main style={{ maxWidth: 520, margin: '0 auto', padding: 24 }}>
      <p style={{ color: '#888', margin: 0 }}>Explora</p>
      <h1 style={{ fontSize: 40, margin: '0 0 16px', textTransform: 'uppercase', letterSpacing: -1 }}>Noticias</h1>

      <p style={{ color: '#888', fontSize: 14 }}>
        {fecha} · origen: {origen === 'ia' ? 'IA (Gemini)' : 'demo'} · endpoint: <code>/api/news?tema={tema}</code>
      </p>
      <ol style={{ lineHeight: 1.5, paddingLeft: 20 }}>
        {noticias.map((n, i) => (
          <li key={i} style={{ marginBottom: 16 }}>
            {n}
          </li>
        ))}
      </ol>
    </main>
  );
}
