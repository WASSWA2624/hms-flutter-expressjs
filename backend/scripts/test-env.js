const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

const TEST_ENV_FILE = path.resolve(__dirname, '..', '.env.test');

const DEFAULT_TEST_ENV = Object.freeze({
  NODE_ENV: 'test',
  DATABASE_URL: 'mysql://hms_test:hms_test@127.0.0.1:3306/hms_test',
  JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
  CORS_ORIGINS: 'http://127.0.0.1:8081,http://localhost:8081',
  PORT: '3001',
  HOST: '127.0.0.1',
  TRUST_PROXY: 'false',
  HANDLE_SIGINT: 'false',
  ALLOW_PRIVATE_NETWORK_ORIGINS: 'false',
  STORAGE_PROVIDER: 'local',
  OTEL_ENABLED: 'false',
});

const LOCAL_DATABASE_HOSTS = new Set(['localhost', '127.0.0.1', '::1']);
const DANGEROUS_DATABASE_TOKENS = ['prod', 'production', 'live'];

const loadDotEnvTest = () => {
  if (!fs.existsSync(TEST_ENV_FILE)) return {};
  const parsed = dotenv.parse(fs.readFileSync(TEST_ENV_FILE, 'utf8'));
  Object.entries(parsed).forEach(([key, value]) => {
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  });
  return parsed;
};

const resolveTestEnv = () => {
  loadDotEnvTest();
  return {
    ...DEFAULT_TEST_ENV,
    ...process.env,
    NODE_ENV: 'test',
  };
};

const parseDatabaseUrl = (databaseUrl) => {
  try {
    return new URL(databaseUrl);
  } catch (error) {
    throw new Error(`Invalid test DATABASE_URL: ${error.message}`);
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

const redactDatabaseUrl = (databaseUrl) => {
  const parsedUrl = parseDatabaseUrl(databaseUrl);
  if (parsedUrl.password) parsedUrl.password = '***';
  if (parsedUrl.username) parsedUrl.username = parsedUrl.username.replace(/.+/, '***');
  return parsedUrl.toString();
};

const assertSafeTestEnv = (env) => {
  if (env.NODE_ENV !== 'test') {
    throw new Error('Refusing to run tests unless NODE_ENV is exactly "test".');
  }

  if (!env.JWT_SECRET || String(env.JWT_SECRET).length < 32) {
    throw new Error('JWT_SECRET must be set to a non-production value with at least 32 characters.');
  }

  if (!env.CORS_ORIGINS || !String(env.CORS_ORIGINS).trim()) {
    throw new Error('CORS_ORIGINS must be set for backend tests.');
  }

  const parsedUrl = parseDatabaseUrl(env.DATABASE_URL);
  const protocol = String(parsedUrl.protocol || '').toLowerCase();
  if (!['mysql:', 'mysql2:'].includes(protocol)) {
    throw new Error(`Unsupported test DATABASE_URL protocol "${parsedUrl.protocol}". Expected mysql.`);
  }

  const databaseName = resolveDatabaseName(parsedUrl);
  if (!databaseName || !databaseName.toLowerCase().includes('test')) {
    throw new Error('Refusing to run database-aware tests unless the DATABASE_URL database name includes "test".');
  }

  const host = String(parsedUrl.hostname || '').toLowerCase();
  const isLocalHost = LOCAL_DATABASE_HOSTS.has(host);
  const allowRemote = String(env.ALLOW_REMOTE_TEST_DATABASE || '').toLowerCase() === 'true';
  if (!isLocalHost && !allowRemote) {
    throw new Error(
      `Refusing to use remote test database host "${host}". Set ALLOW_REMOTE_TEST_DATABASE=true only for isolated disposable test databases.`
    );
  }

  const unsafeParts = [host, databaseName, parsedUrl.username].filter(Boolean).join(' ');
  if (hasDangerousDatabaseToken(unsafeParts)) {
    throw new Error('Refusing to run tests because DATABASE_URL appears to reference a production/live database.');
  }

  return true;
};

const installTestEnv = () => {
  const env = resolveTestEnv();
  assertSafeTestEnv(env);
  Object.entries(env).forEach(([key, value]) => {
    if (value !== undefined && value !== null) {
      process.env[key] = String(value);
    }
  });
  return env;
};

module.exports = {
  TEST_ENV_FILE,
  DEFAULT_TEST_ENV,
  assertSafeTestEnv,
  installTestEnv,
  parseDatabaseUrl,
  redactDatabaseUrl,
  resolveTestEnv,
};
