/**
 * Landing Page - HOSSPI HMS product page
 *
 * Server Component. Introduces the HOSSPI Hospital Management System to
 * hospitals evaluating it: what it covers, who it serves, how packages work,
 * and where to try it.
 */

import { Section } from '@/components/ui';
import { StructuredData } from '@/components/common';
import {
  MarketingHero,
  KeyFigures,
  FeatureGrid,
  ModuleGrid,
  JourneyList,
  PlanGrid,
  RoleGrid,
  FaqList,
  CallToAction,
} from '@/components/marketing';
import {
  APP_NAME,
  APP_URL,
  APP_LOGIN_URL,
  COMPANY_NAME,
  COMPANY_ADDRESS,
  COMPANY_PHONE,
  CONTACT_EMAIL,
} from '@/lib/constants';
import {
  HMS_NAME,
  HMS_TAGLINE,
  HMS_SUMMARY,
  HMS_INTRO,
  PLATFORMS,
  KEY_FIGURES,
  VALUE_PROPS,
  AVAILABLE_MODULES,
  CARE_JOURNEYS,
  PLANS,
  PLANS_NOTE,
  HEADLINE_ROLES,
  HEADLINE_ROLES_NOTE,
  FAQS,
} from '@/lib/product';

const PAGE_DESCRIPTION =
  'HOSSPI is a complete hospital management system covering registration, outpatient and inpatient care, theatre, laboratory, radiology, pharmacy, billing and accounts — on web, Android, iOS, desktop and Linux.';

export const metadata = {
  title: {
    absolute: `${HMS_NAME} — ${HMS_TAGLINE}`,
  },
  description: PAGE_DESCRIPTION,
  keywords: [
    'hospital management system',
    'HMS',
    'HOSSPI',
    'patient records',
    'hospital software',
    'clinic management software',
    'electronic medical records',
  ],
  alternates: {
    canonical: APP_URL,
  },
  openGraph: {
    title: `${HMS_NAME} — ${HMS_TAGLINE}`,
    description: PAGE_DESCRIPTION,
    url: APP_URL,
    siteName: APP_NAME,
    images: [
      {
        url: `${APP_URL}/logos/og-image.png`,
        width: 1200,
        height: 630,
        alt: HMS_NAME,
      },
    ],
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: `${HMS_NAME} — ${HMS_TAGLINE}`,
    description: PAGE_DESCRIPTION,
    images: [`${APP_URL}/logos/og-image.png`],
  },
};

export const revalidate = 3600;

export default function Home() {
  const softwareSchema = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: HMS_NAME,
    applicationCategory: 'HealthApplication',
    operatingSystem: 'Web, Android, iOS, Windows, macOS, Linux',
    description: HMS_SUMMARY,
    url: APP_LOGIN_URL,
    featureList: AVAILABLE_MODULES.flatMap((group) => group.items),
    publisher: {
      '@type': 'Organization',
      name: COMPANY_NAME,
      url: APP_URL,
      logo: `${APP_URL}/logos/icon-512.png`,
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
    },
  };

  const faqSchema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: FAQS.map((faq) => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: { '@type': 'Answer', text: faq.answer },
    })),
  };

  return (
    <>
      <StructuredData data={softwareSchema} />
      <StructuredData data={faqSchema} />

      {/* The header carries the brand mark and the call to action, so the hero
          opens on the headline itself. */}
      <MarketingHero
        eyebrow="Hospital Management System"
        title={HMS_TAGLINE}
        subtitle={HMS_SUMMARY}
        platforms={PLATFORMS}
      />

      <Section tone="alt">
        <KeyFigures figures={KEY_FIGURES} />
      </Section>

      {/* What it is, then what you get, then how it works, then who uses it.
          Scope before mechanics: a reader evaluating the system wants the
          department list before the workflow narrative. */}
      <Section
        id="why"
        eyebrow="Why HOSSPI"
        title="Built around how a hospital actually runs"
        description={HMS_INTRO}
      >
        <FeatureGrid features={VALUE_PROPS} />
      </Section>

      <Section
        id="modules"
        tone="alt"
        eyebrow="What's included"
        title="Twenty-six departments, one system"
        description="Grouped the way the application itself is, and every area below is available today. They share the same patient record, so work handed from one department to the next arrives complete."
      >
        <ModuleGrid modules={AVAILABLE_MODULES} />
      </Section>

      <Section
        id="journeys"
        eyebrow="How it works"
        title="Follow a patient through the hospital"
        description="The system is organised the way care actually moves, so each step picks up exactly where the last one finished."
      >
        <JourneyList journeys={CARE_JOURNEYS} />
      </Section>

      <Section
        id="roles"
        tone="alt"
        eyebrow="Who it's for"
        title="A workspace for every member of staff"
        description="People see what their job needs and nothing more."
      >
        <RoleGrid roles={HEADLINE_ROLES} note={HEADLINE_ROLES_NOTE} />
      </Section>

      <Section
        id="plans"
        eyebrow="Packages"
        title="Start small, grow into it"
        description="Begin with the essentials and move up as your facility takes on more."
      >
        <PlanGrid plans={PLANS} note={PLANS_NOTE} />
      </Section>

      {/* The roadmap is a list of what the system does not do yet — weak
          material for a landing page, and the guide carries it in full. */}
      <Section
        id="faq"
        tone="alt"
        eyebrow="Questions"
        title="Common questions"
        description="What evaluating facilities ask first. The guide goes further, including what we are building next."
      >
        <FaqList faqs={FAQS} />
      </Section>

      <CallToAction
        title="See it running in your hospital"
        body="Open the app to explore it yourself, or talk to us about fitting HOSSPI to how your facility works."
        appUrl={APP_LOGIN_URL}
        primaryLabel="Open the app"
        secondaryLabel="Talk to us"
        secondaryHref="/contact"
      />
    </>
  );
}
