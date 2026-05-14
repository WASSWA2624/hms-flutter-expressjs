const prisma = require('@prisma/client');
const mysql = require('mysql2/promise');
const { DATABASE_URL } = require('@config/env');

const MYSQL_STARTUP_TIMEOUT_MS = 5000;
const SCHEMA_DRIFT_ERROR_CODE = 'SCHEMA_DRIFT_MISSING_ARTIFACTS';
const REQUIRED_SCHEMA = Object.freeze({
  user_permission: Object.freeze({
    columns: Object.freeze([
      'id',
      'human_friendly_id',
      'user_id',
      'permission_id',
      'created_at',
      'updated_at',
      'deleted_at',
      'version',
    ]),
  }),
});

const escapeSqlLiteral = (value) => String(value).replace(/'/g, "''");

const toSqlStringList = (values = []) =>
  values.map((value) => `'${escapeSqlLiteral(value)}'`).join(', ');

const formatMissingSchemaArtifactsMessage = (artifacts = []) => {
  const artifactLabel = artifacts.length === 1 ? 'artifact' : 'artifacts';
  return `Database schema is behind. Missing required schema ${artifactLabel}: ${artifacts.join(', ')}. Apply pending Prisma migrations with \`npm run prisma:migrate:deploy\`.`;
};

const collectErrorMessages = (error, seen = new Set(), messages = []) => {
  if (!error) return messages;

  const isObjectLike = typeof error === 'object' || typeof error === 'function';
  if (isObjectLike) {
    if (seen.has(error)) return messages;
    seen.add(error);
  }

  const message = typeof error?.message === 'string' ? error.message.trim() : '';
  if (message) {
    messages.push(message);
  }

  const nestedCandidates = [
    error?.cause,
    error?.originalError,
    error?.meta?.cause,
    error?.meta?.driverAdapterError,
    error?.meta?.driverAdapterError?.cause,
  ];

  nestedCandidates.forEach((candidate) => {
    collectErrorMessages(candidate, seen, messages);
  });

  return messages;
};

const prioritizeMessage = (messages = []) => {
  const uniqueMessages = Array.from(
    new Set(
      messages
        .map((entry) => String(entry || '').trim())
        .filter(Boolean)
    )
  );

  const priorityPatterns = [
    /access denied/i,
    /unknown database/i,
    /can(?:not|'t) connect|can(?:not|'t) reach|econnrefused|connection refused/i,
    /timed out|timeout/i,
    /pool timeout/i,
  ];

  for (const pattern of priorityPatterns) {
    const match = uniqueMessages.find((entry) => pattern.test(entry));
    if (match) return match;
  }

  return uniqueMessages[0] || 'Database connection failed';
};

const resolveDatabaseStartupErrorMessage = (error) => {
  return prioritizeMessage(collectErrorMessages(error));
};

const findMissingRequiredSchemaArtifacts = async () => {
  const requiredTables = Object.keys(REQUIRED_SCHEMA);
  if (requiredTables.length === 0) {
    return [];
  }

  const existingColumns = await prisma.$queryRawUnsafe(`
    SELECT
      TABLE_NAME AS table_name,
      COLUMN_NAME AS column_name
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME IN (${toSqlStringList(requiredTables)})
  `);

  const columnsByTable = new Map();
  (existingColumns || []).forEach((row) => {
    const tableName = String(row?.table_name || row?.TABLE_NAME || '').trim();
    const columnName = String(row?.column_name || row?.COLUMN_NAME || '').trim();
    if (!tableName || !columnName) {
      return;
    }

    if (!columnsByTable.has(tableName)) {
      columnsByTable.set(tableName, new Set());
    }
    columnsByTable.get(tableName).add(columnName);
  });

  const missingArtifacts = [];

  requiredTables.forEach((tableName) => {
    const expectedColumns = REQUIRED_SCHEMA[tableName]?.columns || [];
    const existingColumnSet = columnsByTable.get(tableName);

    if (!existingColumnSet || existingColumnSet.size === 0) {
      missingArtifacts.push(`table \`${tableName}\``);
      return;
    }

    expectedColumns.forEach((columnName) => {
      if (!existingColumnSet.has(columnName)) {
        missingArtifacts.push(`column \`${tableName}.${columnName}\``);
      }
    });
  });

  return missingArtifacts;
};

const probeDatabaseDirectly = async () => {
  const url = new URL(DATABASE_URL);

  let connection = null;
  try {
    connection = await mysql.createConnection({
      host: url.hostname,
      port: Number.parseInt(url.port || '3306', 10),
      user: url.username,
      password: url.password,
      database: url.pathname.replace(/^\//, ''),
      connectTimeout: MYSQL_STARTUP_TIMEOUT_MS,
    });
    await connection.query('SELECT 1');
    return null;
  } catch (error) {
    return error;
  } finally {
    if (connection) {
      try {
        await connection.end();
      } catch {
        // Best-effort cleanup only.
      }
    }
  }
};

const assertDatabaseConnection = async () => {
  try {
    await prisma.$queryRawUnsafe('SELECT 1');

    const missingSchemaArtifacts = await findMissingRequiredSchemaArtifacts();
    if (missingSchemaArtifacts.length > 0) {
      const schemaError = new Error(
        formatMissingSchemaArtifactsMessage(missingSchemaArtifacts)
      );
      schemaError.code = SCHEMA_DRIFT_ERROR_CODE;
      schemaError.missingArtifacts = missingSchemaArtifacts;
      throw schemaError;
    }

    return true;
  } catch (error) {
    if (error?.code === SCHEMA_DRIFT_ERROR_CODE) {
      try {
        await prisma.$disconnect();
      } catch {
        // Best-effort cleanup only.
      }

      throw error;
    }

    const directProbeError = await probeDatabaseDirectly();
    const startupError = new Error(
      resolveDatabaseStartupErrorMessage(directProbeError || error)
    );
    startupError.code = error?.code || null;
    startupError.cause = error;
    startupError.directCause = directProbeError || null;

    try {
      await prisma.$disconnect();
    } catch {
      // Best-effort cleanup only.
    }

    throw startupError;
  }
};

module.exports = {
  assertDatabaseConnection,
  resolveDatabaseStartupErrorMessage,
  formatMissingSchemaArtifactsMessage,
};
