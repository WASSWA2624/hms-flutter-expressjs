/**
 * Readiness Check Utility
 *
 * Checks if application is ready to serve traffic per health-checks.mdc:
 * - Primary database check via Prisma query with 2s timeout.
 * - Fallback direct mysql2 connectivity check with 5s timeout.
 * - Total DB check budget is bounded by the primary + fallback path.
 */

const { getCurrentISO } = require('@lib/dates');
const { logger } = require('@lib/logging');
const { DATABASE_URL } = require('@config/env');

const READINESS_CACHE_TTL_MS = 5000;
const PRISMA_TIMEOUT_MS = 2000;
const MYSQL_TIMEOUT_MS = 5000;

let lastDatabaseCheckAt = 0;
let lastDatabaseCheckResult = null;

/**
 * Race a promise with a timeout and clear timer when done.
 *
 * @param {Promise<any>} promise - Promise to guard
 * @param {number} timeoutMs - Timeout in milliseconds
 * @param {string} timeoutMessage - Error message on timeout
 * @returns {Promise<any>} Promise result
 */
const withTimeout = async (promise, timeoutMs, timeoutMessage) => {
  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error(timeoutMessage)), timeoutMs);
    if (typeof timeoutId.unref === 'function') {
      timeoutId.unref();
    }
  });

  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
  }
};

/**
 * Get initialized Prisma client if available.
 *
 * @returns {Object|null} Prisma client or null
 */
const getInitializedPrismaClient = () => {
  if (globalThis.prisma && typeof globalThis.prisma.$queryRaw === 'function') {
    return globalThis.prisma;
  }
  return null;
};

/**
 * Primary readiness check using Prisma.
 *
 * @returns {Promise<{status: string, source: string}>} Database check result
 */
const checkDatabaseWithPrisma = async () => {
  const prisma = getInitializedPrismaClient();
  if (!prisma) {
    throw new Error('Prisma client not initialized');
  }

  await withTimeout(
    prisma.$queryRaw`SELECT 1`,
    PRISMA_TIMEOUT_MS,
    'Prisma readiness check timeout'
  );

  return { status: 'ok', source: 'prisma' };
};

/**
 * Fallback readiness check using direct mysql2 connection.
 *
 * @returns {Promise<{status: string, source: string, error?: string}>} Database check result
 */
const checkDatabaseDirect = async () => {
  let connection = null;

  try {
    const mysql = require('mysql2/promise');
    const urlObj = new URL(DATABASE_URL);

    connection = await withTimeout(
      mysql.createConnection({
        host: urlObj.hostname,
        port: parseInt(urlObj.port || '3306', 10),
        user: urlObj.username,
        password: urlObj.password,
        database: urlObj.pathname.substring(1),
        connectTimeout: MYSQL_TIMEOUT_MS
      }),
      MYSQL_TIMEOUT_MS,
      'mysql2 readiness connection timeout'
    );

    await withTimeout(
      connection.query('SELECT 1'),
      MYSQL_TIMEOUT_MS,
      'mysql2 readiness query timeout'
    );

    return { status: 'ok', source: 'mysql2' };
  } catch (err) {
    return {
      status: 'error',
      source: 'mysql2',
      error: err?.message || err?.code || 'Database connection failed'
    };
  } finally {
    if (connection) {
      try {
        await connection.end();
      } catch (_) {
        // ignore connection close errors in readiness path
      }
    }
  }
};

/**
 * Check database connectivity with Prisma primary and mysql2 fallback.
 *
 * @returns {Promise<{status: string, source: string, error?: string}>} Database check result
 */
const checkDatabase = async () => {
  const now = Date.now();
  if (lastDatabaseCheckResult && now - lastDatabaseCheckAt < READINESS_CACHE_TTL_MS) {
    return lastDatabaseCheckResult;
  }

  let prismaError = null;
  try {
    const prismaResult = await checkDatabaseWithPrisma();
    lastDatabaseCheckAt = now;
    lastDatabaseCheckResult = prismaResult;
    return prismaResult;
  } catch (error) {
    prismaError = error;
  }

  const fallbackResult = await checkDatabaseDirect();
  if (fallbackResult.status === 'ok') {
    logger.warn('Readiness DB check used mysql2 fallback after Prisma failure', {
      error: prismaError?.message || 'unknown'
    });
  } else {
    logger.warn('Database readiness check failed', {
      prisma_error: prismaError?.message || 'unknown',
      fallback_error: fallbackResult.error
    });
  }

  const result =
    fallbackResult.status === 'ok'
      ? fallbackResult
      : {
          status: 'error',
          source: 'mysql2',
          error: fallbackResult.error || prismaError?.message || 'Database unavailable'
        };

  lastDatabaseCheckAt = now;
  lastDatabaseCheckResult = result;
  return result;
};

/**
 * Readiness check function.
 *
 * @returns {Promise<Object>} Readiness check response
 */
const readinessCheck = async () => {
  const timestamp = getCurrentISO();
  const dbCheck = await checkDatabase();
  const checks = {
    database: dbCheck.status
  };

  const status = checks.database === 'ok' ? 'ready' : 'not_ready';

  return {
    status,
    timestamp,
    checks
  };
};

module.exports = { readinessCheck };

