import { TEMAS, esTema, obtenerResumen } from '@/lib/news';

export const dynamic = 'force-dynamic';

const LIMA = '#C6FF00';

// Página de verificación: muestra lo mismo que recibirá el reloj para cada tema.
export default async function Home({ searchParams }: { searchParams: Promise<{ tema?: string }> }) {
  const { tema: valor } = await searchParams;
  const tema = esTema(valor) ? valor : 'mundo';
  const { fecha, noticias, categorias, origen } = await obtenerResumen(tema);

  return (
    <main style={{ maxWidth: 520, margin: '0 auto', padding: 24 }}>
      <p style={{ color: '#888', margin: 0 }}>Explora</p>
      <h1 style={{ fontSize: 40, margin: '0 0 16px', textTransform: 'uppercase', letterSpacing: -1 }}>Noticias</h1>

      <nav style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 24 }}>
        {Object.keys(TEMAS).map((t) => (
          <a
            key={t}
            href={`/?tema=${t}`}
            style={{
              padding: '6px 14px',
              borderRadius: 999,
              textDecoration: 'none',
              fontSize: 14,
              background: t === tema ? LIMA : '#222',
              color: t === tema ? '#000' : '#ccc',
            }}
          >
            {t}
          </a>
        ))}
      </nav>

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
