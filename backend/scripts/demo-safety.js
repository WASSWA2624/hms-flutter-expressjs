const env = require('@config/env');

const DANGEROUS_DATABASE_TOKENS = Object.freeze(['prod', 'production', 'live']);

/**
 * Opt-in escape hatch for the one demo task that is safe against a production
 * database: the demo seed, whose packs all upsert on deterministic IDs, so a
 * re-run updates demo rows in place and clears nothing.
 *
 * The override only applies where a caller explicitly passes
 * `allowProductionOverride: true`. Destructive callers - clear-demo-data and
 * clean-duplicate-encounters - do not, so setting this variable cannot unlock
 * them.
 */
const PRODUCTION_OVERRIDE_VAR = 'ALLOW_PRODUCTION_DEMO_SEED';

const isProductionOverrideRequested = () =>
  String(process.env[PRODUCTION_OVERRIDE_VAR] || '').trim() === '1';

const parseDatabaseUrl = (databaseUrl) => {
  try {
    return new URL(databaseUrl);
  } catch (error) {
    throw new Error(`Invalid DATABASE_URL for demo script: ${error.message}`);
  }
};

const resolveDatabaseName = (parsedUrl) =>
  decodeURIComponent(String(parsedUrl.pathname || '').replace(/^\/+/, '')).trim();

const hasDangerousDatabaseToken = (value) => {
  const normalized = String(value || '').toLowerCase();
  return DANGEROUS_DATABASE_TOKENS.some((token) => {
    const pattern = new RegExp(`(^|[^a-z0-9])${token}([^a-z0-9]|$)`, 'i');
    return pattern.test(normalized);
  });
};

const assertDemoTaskAllowed = (taskName, { allowProductionOverride = false } = {}) => {
  if (env.NODE_ENV === 'production') {
    if (!allowProductionOverride || !isProductionOverrideRequested()) {
      return { allowed: false, reason: 'production_environment' };
    }
  }

  const parsedUrl = parseDatabaseUrl(env.DATABASE_URL);
  const unsafeParts = [
    parsedUrl.hostname,
    parsedUrl.username,
    resolveDatabaseName(parsedUrl),
  ].filter(Boolean).join(' ');

  if (hasDangerousDatabaseToken(unsafeParts)) {
    throw new Error(
      `Refusing to run ${taskName}: DATABASE_URL appears to reference a production/live database.`
    );
  }

  return { allowed: true, reason: null };
};

module.exports = {
  PRODUCTION_OVERRIDE_VAR,
  assertDemoTaskAllowed,
  hasDangerousDatabaseToken,
  parseDatabaseUrl,
  resolveDatabaseName,
};
