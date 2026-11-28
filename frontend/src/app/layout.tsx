import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { Providers } from '@/components/providers';
import { SiteShell } from '@/components/site-shell';
import './globals.css';
import './public-pages.css';

export const metadata: Metadata = {
  title: 'Seed Vault',
  description: 'Seed vault information system',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ru">
      <body>
        <Providers>
          <SiteShell>{children}</SiteShell>
        </Providers>
      </body>
    </html>
  );
}
