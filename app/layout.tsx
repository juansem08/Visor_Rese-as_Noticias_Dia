import type { ReactNode } from 'react';

export const metadata = {
  title: 'Noticias del Día – Backend',
  description: 'Backend del visor de noticias para Garmin Forerunner 165',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="es">
      <body style={{ margin: 0, background: '#000', color: '#fff', fontFamily: 'system-ui, sans-serif' }}>
        {children}
      </body>
    </html>
  );
}
