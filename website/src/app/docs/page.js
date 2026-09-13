/**
 * Docs Page - User guide for the HOSSPI Hospital Management System
 *
 * Server Component. Written for hospital staff and administrators: what the
 * system covers, how care moves through it, who does what, how packages work,
 * and how to get started.
 */

import { Section } from '@/components/ui';
import { StructuredData } from '@/components/common';
import {
  AppLink,
  PlatformGrid,
  ModuleGrid,
  JourneyList,
  RoleGrid,
  PlanGrid,
  RoadmapList,
  FaqList,
} from '@/components/marketing';
import { APP_NAME, APP_URL, APP_LOGIN_URL } from '@/lib/constants';
import {
  HMS_NAME,
  HMS_INTRO,
  AVAILABLE_MODULES,
  CARE_JOURNEYS,
  ROLES,
  ROLES_NOTE,
  PLANS,
  PLANS_NOTE,
  ROADMAP,
  FAQS,
  PLATFORMS,
} from '@/lib/product';

const PAGE_DESCRIPTION = `A guide to ${HMS_NAME}: what the system covers, how a patient moves through it, what each member of staff can do, and how packages work.`;

export const metadata = {
  title: 'Guide',
  description: PAGE_DESCRIPTION,
  keywords: [
    'HOSSPI guide',
    'hospital management system guide',
    'HMS user guide',
    'hospital software documentation',
  ],
  alternates: {
    canonical: `${APP_URL}/docs`,
  },
  openGraph: {
    title: `Guide | ${HMS_NAME}`,
    description: PAGE_DESCRIPTION,
    url: `${APP_URL}/docs`,
    siteName: APP_NAME,
    images: [
      {
        url: `${APP_URL}/logos/og-image.png`,
        width: 1200,
        height: 630,
        alt: HMS_NAME,
      },
    ],
    type: 'article',
  },
  twitter: {
    card: 'summary_large_image',
    title: `Guide | ${HMS_NAME}`,
    description: PAGE_DESCRIPTION,
    images: [`${APP_URL}/logos/og-image.png`],
  },
};

export const revalidate = 3600;

export default function DocsPage() {

  const guideSchema = {
    '@context': 'https://schema.org',
    '@type': 'TechArticle',
    headline: `${HMS_NAME} guide`,
    description: PAGE_DESCRIPTION,
    url: `${APP_URL}/docs`,
    about: {
      '@type': 'SoftwareApplication',
      name: HMS_NAME,
      applicationCategory: 'HealthApplication',
      url: APP_LOGIN_URL,
    },
  };

  return (
    <>
      <StructuredData data={guideSchema} />

      <Section
        id="start"
        eyebrow="Guide"
        title="Getting started with HOSSPI"
        description={HMS_INTRO}
        headingLevel="h1"
      >
        <AppLink
          href={APP_LOGIN_URL}
          label="Open the app"
          note="Sign in from any browser. Nothing to install to get started."
        />
      </Section>

      <Section
        id="platforms"
        tone="alt"
        eyebrow="Where it runs"
        title="Works on what your staff already carry"
        description="One account, the same records, whichever way your team signs in."
      >
        <PlatformGrid platforms={PLATFORMS} />
      </Section>

      <Section
        id="modules"
        tone="alt"
        eyebrow="Coverage"
        title="What the system covers"
        description="Every area below is available today, working from one shared patient record."
      >
        <ModuleGrid modules={AVAILABLE_MODULES} />
      </Section>

      <Section
        id="journeys"
        eyebrow="Day to day"
        title="How a patient moves through HOSSPI"
        description="Each step hands its record to the next, so nothing is entered twice and nothing is lost between departments."
      >
        <JourneyList journeys={CARE_JOURNEYS} />
      </Section>

      <Section
        id="roles"
        tone="alt"
        eyebrow="Your team"
        title="What each member of staff can do"
        description="Staff are given a role when their account is created, and that role decides which parts of the system they reach."
      >
        <RoleGrid roles={ROLES} note={ROLES_NOTE} />
      </Section>

      <Section
        id="packages"
        eyebrow="Packages"
        title="Choosing a package"
        description="Your package decides which areas of the system your facility can open. You can change it as you grow."
      >
        <PlanGrid plans={PLANS} note={PLANS_NOTE} />
      </Section>

      <Section
        id="roadmap"
        tone="alt"
        eyebrow="Coming next"
        title="Not available yet"
        description="These areas are planned for future releases, so you can plan around them."
      >
        <RoadmapList items={ROADMAP} />
      </Section>

      <Section id="faq" eyebrow="Questions" title="Frequently asked">
        <FaqList faqs={FAQS} />
      </Section>
    </>
  );
}
