/**
 * ESLint flat config.
 *
 * Next 16 dropped the `next lint` command, and ESLint 9+ no longer reads
 * `.eslintrc.json`, so the config lives here and `npm run lint` calls eslint
 * directly. `eslint-config-next/core-web-vitals` already exports a flat-config
 * array, so it spreads in without the FlatCompat shim.
 *
 * @file eslint.config.mjs
 */

import coreWebVitals from 'eslint-config-next/core-web-vitals';

const config = [
  {
    ignores: ['.next/**', 'node_modules/**'],
  },
  ...coreWebVitals,
];

export default config;
