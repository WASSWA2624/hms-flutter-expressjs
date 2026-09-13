/**
 * Contact Page - Ways to reach the HOSSPI team
 *
 * Server Component. Contact channels, what people usually get in touch about,
 * and the enquiry form.
 * @file src/app/contact/page.js
 */
import { headers } from 'next/headers';
import { Section } from '@/components/ui';
import { StructuredData, ContactForm } from '@/components/common';
import { ContactChannels, ChipList, CallToAction } from '@/components/marketing';
import {
  APP_NAME,
  APP_URL,
  APP_LOGIN_URL,
  COMPANY_NAME,
  COMPANY_ADDRESS,
  COMPANY_PHONE,
  CONTACT_EMAIL,
  SOCIAL_LINKS,
  whatsAppLink,
  DEFAULT_LOCALE,
} from '@/lib/constants';
import { HMS_NAME, CONTACT_CHANNELS, CONTACT_INTRO, CONTACT_REASONS } from '@/lib/product';
import { getServerTranslations, resolveLocale } from '@/lib/i18n';

const PAGE_DESCRIPTION = `Talk to the ${COMPANY_NAME} team about ${HMS_NAME}: book a demonstration, discuss packages, or get help with an existing setup.`;

export async function generateMetadata() {
  const headersList = await headers();
  const locale = resolveLocale(headersList.get('x-locale'), null) || DEFAULT_LOCALE;
  const t = await getServerTranslations(locale, 'contact');

  return {
    title: t.contactUs || 'Contact us',
    description: PAGE_DESCRIPTION,
    keywords: ['contact HOSSPI', 'hospital software demo', 'HMS pricing', 'healthcare software support'],
    alternates: {
      canonical: `${APP_URL}/contact`,
    },
    openGraph: {
      title: `${t.contactUs || 'Contact us'} | ${APP_NAME}`,
      description: PAGE_DESCRIPTION,
      url: `${APP_URL}/contact`,
      siteName: APP_NAME,
      type: 'website',
      images: [
        {
          url: `${APP_URL}/logos/og-image.png`,
          width: 1200,
          height: 630,
          alt: HMS_NAME,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title: `${t.contactUs || 'Contact us'} | ${APP_NAME}`,
      description: PAGE_DESCRIPTION,
      images: [`${APP_URL}/logos/og-image.png`],
    },
  };
}

export const revalidate = 3600;

/**
 * Attach live contact values to the channel definitions.
 * @returns {Array<Object>} Channels ready to render
 */
function buildChannels() {
  const values = {
    email: {
      value: CONTACT_EMAIL,
      href: `mailto:${CONTACT_EMAIL}`,
    },
    phone: {
      value: COMPANY_PHONE,
      href: `tel:${COMPANY_PHONE}`,
    },
    whatsapp: {
      value: COMPANY_PHONE,
      // Pre-filled so the visitor only has to press send.
      href: whatsAppLink(
        `Hello HOSSPI, I would like to know more about the hospital management system.`
      ),
      external: true,
      secondary: SOCIAL_LINKS.telegram
        ? { label: 'Telegram', href: SOCIAL_LINKS.telegram }
        : undefined,
    },
    address: {
      value: COMPANY_ADDRESS,
    },
  };

  return CONTACT_CHANNELS.map((channel) => ({ ...channel, ...(values[channel.id] || {}) }));
}

export default async function ContactPage() {
  const headersList = await headers();
  const locale = resolveLocale(headersList.get('x-locale'), null) || DEFAULT_LOCALE;
  const t = await getServerTranslations(locale, 'contact');

  const contactSchema = {
    '@context': 'https://schema.org',
    '@type': 'ContactPage',
    name: `${t.contactUs || 'Contact us'} | ${COMPANY_NAME}`,
    description: PAGE_DESCRIPTION,
    url: `${APP_URL}/contact`,
    mainEntity: {
      '@type': 'Organization',
      name: COMPANY_NAME,
      url: APP_URL,
      email: CONTACT_EMAIL,
      telephone: COMPANY_PHONE,
      address: {
        '@type': 'PostalAddress',
        streetAddress: COMPANY_ADDRESS,
      },
    },
  };

  return (
    <>
      <StructuredData data={contactSchema} />

      <Section
        id="reach-us"
        eyebrow={t.contactUs || 'Contact us'}
        title="Let’s talk about your hospital"
        description={CONTACT_INTRO}
        headingLevel="h1"
      >
        <ContactChannels channels={buildChannels()} />
      </Section>

      <Section
        id="reasons"
        tone="alt"
        eyebrow="Common enquiries"
        title="What people usually ask us about"
      >
        <ChipList items={CONTACT_REASONS} />
      </Section>

      <Section
        id="message"
        eyebrow={t.getInTouch || 'Send a message'}
        title={t.contactUs || 'Contact us'}
        description={t.subtitle}
      >
        <ContactForm />
      </Section>

      <CallToAction
        title="Prefer to look around first?"
        body="Open the application and see how HOSSPI handles registration, consultations, diagnostics and billing."
        appUrl={APP_LOGIN_URL}
        primaryLabel="Open the app"
        secondaryLabel="Read the guide"
        secondaryHref="/docs"
      />
    </>
  );
}
