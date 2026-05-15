const env = require('@config/env');

const DANGEROUS_DATABASE_TOKENS = Object.freeze(['prod', 'production', 'live']);

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

const assertDemoTaskAllowed = (taskName) => {
  if (env.NODE_ENV === 'production') {
    return { allowed: false, reason: 'production_environment' };
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
  assertDemoTaskAllowed,
  hasDangerousDatabaseToken,
  parseDatabaseUrl,
  resolveDatabaseName,
};
