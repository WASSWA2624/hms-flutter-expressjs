/**
 * Root Layout - Main layout wrapper for the entire application
 *
 * @component
 */
import './globals.css';
import { headers } from 'next/headers';
import StyledComponentsRegistry from '@/lib/registry';
import { ThemeProviderWrapper, I18nProvider } from '@/components/common';
import { Header, Footer } from '@/components/layout';
import { APP_NAME, APP_URL, DEFAULT_LOCALE } from '@/lib/constants';
import { HMS_NAME, HMS_SHORT_NAME, HMS_SUMMARY } from '@/lib/product';
import { getLocaleDirection, getServerTranslations, resolveLocale } from '@/lib/i18n';

export const metadata = {
  metadataBase: new URL(APP_URL),
  title: {
    default: HMS_NAME,
    template: `%s | ${HMS_SHORT_NAME}`,
  },
  description: HMS_SUMMARY,
  applicationName: APP_NAME,
  icons: {
    icon: [
      { url: '/logos/icon-32.png', sizes: '32x32', type: 'image/png' },
      { url: '/logos/icon-192.png', sizes: '192x192', type: 'image/png' },
    ],
    shortcut: '/logos/icon-32.png',
    apple: '/logos/icon-192.png',
  },
  openGraph: {
    title: HMS_NAME,
    description: HMS_SUMMARY,
    siteName: APP_NAME,
    images: ['/logos/og-image.png'],
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: HMS_NAME,
    description: HMS_SUMMARY,
    images: ['/logos/og-image.png'],
  },
};

export default async function RootLayout({ children }) {
  const headersList = await headers();
  const locale = resolveLocale(headersList.get('x-locale'), null) || DEFAULT_LOCALE;
  const dir = getLocaleDirection(locale);

  // Preload every namespace so client components render real strings on the
  // first pass instead of falling back to raw translation keys
  const [common, navigation, about, contact] = await Promise.all([
    getServerTranslations(locale, 'common'),
    getServerTranslations(locale, 'navigation'),
    getServerTranslations(locale, 'about'),
    getServerTranslations(locale, 'contact'),
  ]);

  return (
    <html lang={locale} dir={dir} suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('theme');if(t==='dark'||t==='light'){document.documentElement.setAttribute('data-theme',t);}else if(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches){document.documentElement.setAttribute('data-theme','dark');}else{document.documentElement.setAttribute('data-theme','light');}}catch(e){}})();`,
          }}
        />
      </head>
      <body>
        <StyledComponentsRegistry>
          <ThemeProviderWrapper>
            <I18nProvider
              locale={locale}
              initialNamespaces={{ common, navigation, about, contact }}
            >
              <Header />
              <main>{children}</main>
              <Footer />
            </I18nProvider>
          </ThemeProviderWrapper>
        </StyledComponentsRegistry>
      </body>
    </html>
  );
}
