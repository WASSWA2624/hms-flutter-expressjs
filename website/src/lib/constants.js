/**
 * App Constants and Configuration
 * 
 * Centralized configuration constants for the entire application.
 * All app-level constants should be defined here.
 */

// App Information
// Note: For translated versions, use getTranslatedCompanyConstants() from '@/lib/i18n'
// or getCompanyName(), getCompanyDescription() from '@/lib/companyConstants'
export const APP_NAME = 'HOSSPI';
export const APP_DESCRIPTION = 'HOSSPI is a company that provides biomedical and software services to the public, tailored with advanced AI capabilities. Our team of experts is dedicated to delivering cutting-edge solutions in biomedical engineering and software, ensuring the best possible outcomes for our clients.';
export const APP_VERSION = '1.0.0';

// Company Information
// Note: For translated versions, use getTranslatedCompanyConstants() from '@/lib/i18n'
// These constants are kept for backward compatibility and non-translatable contexts
export const COMPANY_NAME = 'HOSSPI';
export const COMPANY_DESCRIPTION = 'HOSSPI delivers advanced biomedical and software solutions, leveraging AI and expertise to serve clients in the biomedical engineering sector. Our commitment is to innovation, quality service, and exceptional outcomes for every client.';

// Company Mission, Vision, and Values
// Note: These are now translatable. Use getTranslatedCompanyConstants() from '@/lib/i18n'
// or getCompanyMission(), getCompanyVision(), getCompanyValues() from '@/lib/companyConstants'
// These constants are kept for backward compatibility and fallback
export const COMPANY_MISSION = 'Delivering innovative biomedical and software solutions to advance healthcare and improve quality of life worldwide.';
export const COMPANY_VISION = 'To be the leading provider of biomedical expertise and solutions, recognized globally for our commitment to excellence, innovation, and patient care.';
export const COMPANY_VALUES = [
  'Excellence in everything we do',
  'Innovation and continuous improvement',
  'Integrity and ethical practices',
  'Patient-centered care',
  'Collaboration and teamwork',
];

// Company History
// Note: This is now translatable. Use getTranslatedCompanyConstants() from '@/lib/i18n'
// or getCompanyHistory() from '@/lib/companyConstants'
// This constant is kept for backward compatibility and fallback
export const COMPANY_HISTORY = [
  {
    year: '2022',
    title: 'Website Launched',
    description: 'HOSSPI website was launched to provide a platform for the company to showcase its products and services.',
  },
  {
    year: '2023',
    title: 'Product Launch',
    description: 'HOSSPI products were launched to the public to help them solve their problems.',
  },
  {
    year: '2024',
    title: 'Product Launch',
    description: 'HOSSPI products were launched to the public to help them solve their problems.',
  },
  {
    year: '2025',
    title: 'Product Launch',
    description: 'HOSSPI products were launched to the public to help them solve their problems.',
  },
  {
    year: '2026',
    title: 'Product Launch',
    description: 'HOSSPI products were launched to the public to help them solve their problems.',
  },
];

// Contact Information
export const COMPANY_ADDRESS = 'Kampala, Uganda';
export const COMPANY_PHONE = '+256783230321'; 

// URLs
export const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
export const API_URL = process.env.NEXT_PUBLIC_API_URL || '/api';

// Contact Information
// Defaults match the HMS platform's reply-to address so enquiries from this
// site land in the same inbox the application already uses.
export const CONTACT_EMAIL = process.env.NEXT_PUBLIC_CONTACT_EMAIL || 'admin@hosspi.com';
export const SUPPORT_EMAIL = process.env.NEXT_PUBLIC_SUPPORT_EMAIL || 'admin@hosspi.com';

// Social Media Links
export const SOCIAL_LINKS = {
  whatsapp: 'https://wa.me/256783230321',
  telegram: 'https://t.me/CHALLENGER2624',
  github: 'https://github.com/WASSWA2624',
};

// Navigation Links (using translation keys)
export const NAVIGATION_LINKS = [
  { href: '/', labelKey: 'nav.home' },
  { href: '/docs', labelKey: 'nav.docs' },
  { href: '/about', labelKey: 'nav.about' },
  { href: '/contact', labelKey: 'nav.contact' },
];

// Footer Links (using translation keys)
export const FOOTER_NAV_LINKS = [
  { href: '/', labelKey: 'nav.home' },
  { href: '/docs', labelKey: 'nav.docs' },
  { href: '/about', labelKey: 'nav.about' },
  { href: '/contact', labelKey: 'nav.contact' },
];

// Translation keys for navigation (for reference)
export const NAVIGATION_LINKS_KEYS = {
  HOME: 'nav.home',
  DOCS: 'nav.docs',
  ABOUT: 'nav.about',
  CONTACT: 'nav.contact',
};

// The HOSSPI Hospital Management System application this site documents
export const APP_LOGIN_URL = 'https://app.hosspi.com';

// Metadata
export const DEFAULT_METADATA = {
  title: APP_NAME,
  description: APP_DESCRIPTION,
  keywords: ['company', 'services', 'website'],
  author: COMPANY_NAME,
};

// Date Formats
export const DATE_FORMAT = 'YYYY-MM-DD';
export const DATETIME_FORMAT = 'YYYY-MM-DD HH:mm:ss';
export const DISPLAY_DATE_FORMAT = 'MMM DD, YYYY';
export const DISPLAY_DATETIME_FORMAT = 'MMM DD, YYYY HH:mm';

// Timeouts and Delays
export const API_TIMEOUT = 30000; // 30 seconds
export const DEBOUNCE_DELAY = 300; // milliseconds
export const TOAST_DURATION = 3000; // milliseconds

// Feature Flags (can be controlled via environment variables)
export const FEATURES = {
  DARK_MODE: true,
  ANALYTICS: process.env.NEXT_PUBLIC_ENABLE_ANALYTICS === 'true',
  MAINTENANCE_MODE: process.env.NEXT_PUBLIC_MAINTENANCE_MODE === 'true',
};

// Internationalization (i18n)
export const SUPPORTED_LOCALES = ['en', 'es', 'fr', 'de', 'it', 'pt', 'zh', 'ja', 'ar'];
export const DEFAULT_LOCALE = 'en';
export const LOCALE_NAMES = {
  en: 'English',
  es: 'Español',
  fr: 'Français',
  de: 'Deutsch',
  it: 'Italiano',
  pt: 'Português',
  zh: '中文',
  ja: '日本語',
  ar: 'العربية',
};

// Environment
export const IS_PRODUCTION = process.env.NODE_ENV === 'production';
export const IS_DEVELOPMENT = process.env.NODE_ENV === 'development';
export const IS_TEST = process.env.NODE_ENV === 'test';

