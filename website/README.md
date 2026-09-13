# HOSSPI

Product and documentation site for the **HOSSPI Hospital Management System**
([app.hosspi.com](https://app.hosspi.com)), a static, multilingual site built with
Next.js and Styled Components. It advertises the product to hospitals evaluating it
and documents how the system works for the people using it.

## Tech Stack

- **Framework**: Next.js 16 (App Router)
- **Language**: JavaScript (ES6+)
- **Styling**: Styled Components
- **Data**: No database: content lives in `src/lib/constants.js` and `src/locales/`
- **Email**: Nodemailer (contact form only)

## Pages

| Route | Description |
|-------|-------------|
| `/` | Product page: hero, key figures, value propositions, coverage, care journeys, roles, packages, roadmap, FAQ |
| `/docs` | Guide: getting started, coverage, journeys, roles, packages, roadmap, FAQ |
| `/about` | Company story, mission and vision, build principles, enquiry form |
| `/contact` | Contact channels, common enquiries, contact form |

The main menu contains **Home**, **Docs**, **About**, and **Contact**. It renders as
inline horizontal links from 1024px up and collapses to a hamburger menu below that.

### Product content

All copy for every page lives in [`src/lib/product.js`](src/lib/product.js) as
structured data: platforms, value propositions, capability areas, care journeys,
roles, packages, roadmap, FAQ, headline figures, the company story, and contact
channels. Each entry carries an `icon` name. Edit that file to change what the
pages say; the components in `src/components/marketing/` render whatever it
contains.

Two rules govern that file, and both are stated at the top of it:

- **Audience.** It is written for hospital decision-makers and staff. Internal
  engineering detail (repository file names, module or permission keys, release
  gating mechanics, seeding rules) must never appear in it.
- **Accuracy.** Only capabilities users can reach in the current release may be
  described as available. Everything else goes in `ROADMAP` and is described as
  upcoming, never as shipped.

This content is English-only and is not routed through the i18n system, unlike the
site chrome (navigation, footer, about, and contact pages), which is translated.

### Icons

[`src/components/ui/Icon.js`](src/components/ui/Icon.js) holds an inline SVG set
drawn with `currentColor` at a 24x24 viewBox: clinical, platform, finance and
interface glyphs. It is deliberately hand-rolled rather than pulled from an icon
package: no runtime dependency, no unused weight, and the set stays limited to
what the site uses. Add a glyph to the `ICONS` map and reference it by name from
`product.js`.

### Brand assets

`public/logos/` holds the icon at the sizes the site actually requests: `icon-32`
and `icon-192` (favicon and Apple touch icon), `icon-64` (header), `icon-256`
(hero), `icon-512` (structured data), plus the social share card
(`og-image.png`). They are derived from `frontend/assets/logos/favicon.png` in
this repository, which stays the master; the site ships only the exported sizes. The theme in [`src/styles/theme.js`](src/styles/theme.js)
mirrors the application palette (brand primary `#0079FD`, azure tints, ink
`#0D2744`), so the site and the product read as one brand.

## Getting Started

### Prerequisites

- Node.js 18+ and npm

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env.local` file (see `.env.example` for the full list):

```env
NEXT_PUBLIC_APP_URL="http://localhost:3000"

# Contact form delivery (optional: without it, submissions are logged to the console)
SMTP_SERVICE="gmail"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"
SMTP_FROM="your-email@gmail.com"
```

4. Run the development server:
```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
website/
├── src/                    # Source code
│   ├── app/               # Next.js App Router
│   │   ├── api/contact/  # Contact form endpoint
│   │   ├── about/        # About page
│   │   ├── contact/      # Contact page
│   │   ├── layout.js     # Root layout
│   │   ├── page.js       # Landing page
│   │   ├── error.js      # Global error boundary
│   │   ├── not-found.js  # 404 page
│   │   ├── sitemap.js    # Sitemap generator
│   │   └── robots.js     # Robots.txt generator
│   ├── components/        # React components
│   │   ├── layout/       # Header, Footer, Navigation
│   │   ├── ui/           # Reusable UI primitives (Button, Card, Input, Section, Icon)
│   │   ├── marketing/    # All page sections (hero, modules, plans, FAQ, contact)
│   │   └── common/       # Shared components (theme, i18n, forms)
│   ├── hooks/            # useTheme, useTranslation
│   ├── locales/          # Translations: 9 locales × 4 namespaces
│   ├── lib/              # Content and helpers
│   │   ├── product.js   # All HMS product and guide content (English only)
│   │   ├── i18n.js      # Locale detection and translation loading
│   │   ├── constants.js # App constants
│   │   └── registry.js  # Styled Components SSR registry
│   └── styles/           # Theme and global styles
├── public/logos/         # Brand assets - the only static files the site serves
├── .cursor/              # Cursor IDE rules
├── middleware.js         # Locale detection middleware
├── next.config.js        # Next.js configuration
└── jsconfig.json         # Path aliases configuration
```

## Development

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run start` - Start production server

## Environment Variables

All variables are optional; the site runs without any of them.

| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_APP_URL` | Public site URL used for metadata and the sitemap (default: http://localhost:3000) |
| `NEXT_PUBLIC_CONTACT_EMAIL` | Contact email shown in the footer and used as the contact form recipient |
| `NEXT_PUBLIC_SUPPORT_EMAIL` | Support email address |
| `SMTP_SERVICE` / `SMTP_USER` / `SMTP_PASS` / `SMTP_FROM` | Contact form email delivery via a named service (e.g. Gmail) |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_SECURE` | Custom SMTP server (takes precedence over `SMTP_SERVICE`) |
| `SEND_CONFIRMATION_EMAIL` | Send a confirmation email back to the sender |
| `NEXT_PUBLIC_ENABLE_ANALYTICS` | Enable analytics (default: false) |
| `NEXT_PUBLIC_MAINTENANCE_MODE` | Enable maintenance mode (default: false) |

Without SMTP configuration, contact form submissions are logged to the server console instead of emailed.

## Internationalization

Nine locales are supported: English, Spanish, French, German, Italian, Portuguese, Chinese, Japanese, and Arabic (RTL).

- Locale is detected in `middleware.js` from the `locale` cookie, then `Accept-Language`, then the default (`en`).
- The resolved locale is passed to Server Components via the `x-locale` request header and persisted in a cookie.
- Translations live in `src/locales/[locale]/[namespace].json`. Namespaces: `common`, `navigation`, `about`, `contact`.
- The root layout preloads all namespaces so client components render real strings on the first pass.

Adding a locale: add the code to `SUPPORTED_LOCALES` and `LOCALE_NAMES` in `src/lib/constants.js`, then create `src/locales/[locale]/` with all four namespace files.

## Deployment

The site is deployed to [www.hosspi.com](https://www.hosspi.com) as a Next.js
standalone server running under cPanel Passenger. Both halves are scripted:

```bash
python deploy/update-deploys/website.py && python deploy/upload-deploys/website.py
```

The first builds, smoke-tests and packages `deploy/website/website.zip`; the second
uploads it and brings it live. `deploy/README.md` section 7 covers the target, and
`deploy/website/DEPLOY.md` is the same sequence as a manual SSH runbook.

To check a production build locally without deploying:

```bash
npm run build && npm run start
```

## Features

- **Product Page**: What HOSSPI HMS covers, who it serves, how packages work, and where to try it
- **Guide**: Getting started, coverage, care journeys, roles, packages, and FAQ
- **Company Pages**: About and contact pages with company information
- **Contact Form**: Email delivery via Nodemailer with validation and sanitization
- **Multilingual**: 9 locales with automatic detection and RTL support
- **Responsive Design**: Mobile-first, fully responsive
- **Dark Mode**: Theme toggle with system preference detection
- **SEO Optimized**: Meta tags, sitemap, structured data
- **Accessibility**: WCAG compliant, keyboard navigation, screen reader support

## Documentation

- **Coding Standards**: See `.cursor/rules/code-style.mdc`, `components.mdc` and
  `styled-components.mdc`
- **Project Structure**: See `.cursor/rules/project-structure.mdc` for detailed structure
- **Rules**: See `.cursor/rules/` for project rules and conventions

The site was originally built around a product catalogue, an admin panel and a MySQL
database. Those features, and the phased plan that described building them, have been
removed. The site has no database and no authenticated area.
