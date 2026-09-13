/**
 * About Page - Who HOSSPI is and why the system exists
 *
 * Server Component. Company story, mission and vision, how we build, and the
 * milestones behind the product.
 * @file src/app/about/page.js
 */
import { headers } from 'next/headers';
import { Section } from '@/components/ui';
import { StructuredData, ContactForm } from '@/components/common';
import { PillarGrid, KeyFigures, CallToAction } from '@/components/marketing';
import {
  APP_NAME,
  APP_URL,
  APP_LOGIN_URL,
  COMPANY_NAME,
  COMPANY_ADDRESS,
  COMPANY_PHONE,
  CONTACT_EMAIL,
  DEFAULT_LOCALE,
} from '@/lib/constants';
import {
  HMS_NAME,
  COMPANY_STORY,
  COMPANY_APPROACH,
  COMPANY_PRINCIPLES,
  KEY_FIGURES,
} from '@/lib/product';
import { getServerTranslations, resolveLocale } from '@/lib/i18n';

const PAGE_DESCRIPTION = `${COMPANY_NAME} builds ${HMS_NAME}, one dependable system for running hospital care, from registration through to discharge and settlement.`;

export async function generateMetadata() {
  const headersList = await headers();
  const locale = resolveLocale(headersList.get('x-locale'), null) || DEFAULT_LOCALE;
  const t = await getServerTranslations(locale, 'about');

  return {
    title: t.aboutUs || 'About us',
    description: PAGE_DESCRIPTION,
    keywords: ['about HOSSPI', 'hospital software company', 'healthcare technology', 'HMS vendor'],
    alternates: {
      canonical: `${APP_URL}/about`,
    },
    openGraph: {
      title: `${t.aboutUs || 'About us'} | ${APP_NAME}`,
      description: PAGE_DESCRIPTION,
      url: `${APP_URL}/about`,
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
      title: `${t.aboutUs || 'About us'} | ${APP_NAME}`,
      description: PAGE_DESCRIPTION,
      images: [`${APP_URL}/logos/og-image.png`],
    },
  };
}

export const revalidate = 3600;

export default async function AboutPage() {
  const headersList = await headers();
  const locale = resolveLocale(headersList.get('x-locale'), null) || DEFAULT_LOCALE;
  const t = await getServerTranslations(locale, 'about');

  const organizationSchema = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: COMPANY_NAME,
    url: APP_URL,
    logo: `${APP_URL}/logos/icon-512.png`,
    description: PAGE_DESCRIPTION,
    contactPoint: {
      '@type': 'ContactPoint',
      telephone: COMPANY_PHONE,
      contactType: 'Customer Service',
      email: CONTACT_EMAIL,
    },
    address: {
      '@type': 'PostalAddress',
      streetAddress: COMPANY_ADDRESS,
    },
    makesOffer: {
      '@type': 'Offer',
      itemOffered: {
        '@type': 'SoftwareApplication',
        name: HMS_NAME,
        applicationCategory: 'HealthApplication',
        url: APP_LOGIN_URL,
      },
    },
  };

  return (
    <>
      <StructuredData data={organizationSchema} />

      <Section
        id="story"
        eyebrow={t.aboutUs || 'About us'}
        title="The company behind HOSSPI HMS"
        description={COMPANY_STORY}
        headingLevel="h1"
      />

      <Section tone="alt">
        <KeyFigures figures={KEY_FIGURES} />
      </Section>

      <Section
        id="approach"
        eyebrow={t.ourCompany || 'Our company'}
        title="What we are working towards"
      >
        <PillarGrid pillars={COMPANY_APPROACH} />
      </Section>

      <Section
        id="principles"
        tone="alt"
        eyebrow="How we build"
        title="The commitments behind the software"
        description="Hospital software is judged on the worst day, not the best one. These are the things we hold to."
      >
        <PillarGrid pillars={COMPANY_PRINCIPLES} />
      </Section>

      <Section
        id="enquiry"
        eyebrow={t.getInTouch || 'Get in touch'}
        title="Tell us about your facility"
        description="Send us a note about how your hospital runs today and what you would like to change."
      >
        <ContactForm />
      </Section>

      <CallToAction
        title="Ready to look inside?"
        body="Open the application to see how HOSSPI handles a working day, or talk to us first."
        appUrl={APP_LOGIN_URL}
        primaryLabel="Open the app"
        secondaryLabel="Contact us"
        secondaryHref="/contact"
      />
    </>
  );
}
