const path = require('path');
const fs = require('fs');

const prismaClientPackagePath = path.resolve(__dirname, '..', '..', 'node_modules', '@prisma', 'client');
const generatedPrismaClientEntry = path.resolve(
  __dirname,
  '..',
  '..',
  'node_modules',
  '.prisma',
  'client',
  'default.js'
);

if (!fs.existsSync(generatedPrismaClientEntry)) {
  throw new Error(
    `Generated Prisma client not found at ${generatedPrismaClientEntry}. ` +
      `Run 'npm run prisma:generate' before starting the backend.`
  );
}

const prismaPackage = require(prismaClientPackagePath);
const { PrismaClient } = prismaPackage;
const Prisma = prismaPackage.Prisma || null;

// Import MariaDB adapter for MySQL (Prisma 7.x requirement)
const { PrismaMariaDb } = require('@prisma/adapter-mariadb');
const {
  withTenantGuard,
  buildTenantGuardModelMetadata
} = require('./tenant-guard');

const loadEnvConfig = () => {
  try {
    return require('@config/env');
  } catch (error) {
    const isMissingConfigAlias =
      error?.code === 'MODULE_NOT_FOUND' &&
      typeof error?.message === 'string' &&
      error.message.includes("'@config/env'");

    if (!isMissingConfigAlias) {
      throw error;
    }

    // Support requiring Prisma client from scripts/CI where runtime aliases are not pre-registered.
    return require('../config/env');
  }
};

const {
  NODE_ENV,
  DATABASE_URL,
  PRISMA_POOL_CONNECTION_LIMIT,
  PRISMA_POOL_CONNECT_TIMEOUT_MS,
  PRISMA_POOL_ACQUIRE_TIMEOUT_MS,
  PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL,
} = loadEnvConfig();

const FRIENDLY_ID_PREFIX_LENGTH = 3;
const DEFAULT_FRIENDLY_ID_PADDING = 7;
const FRIENDLY_ID_COUNTER_RETRIES = 3;
const UNKNOWN_MODEL_PREFIX = 'XXX';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FRIENDLY_ID_REGEX = /^[A-Z]{3}\d{7}$/;

const SYSTEM_MODELS = new Set(['human_id_counter']);

const MODEL_PREFIX_OVERRIDES = Object.freeze({
  tenant: 'TEN',
  facility: 'FAC',
  branch: 'BRA',
  department: 'DEP',
  unit: 'UNI',
  ward: 'WRD',
  room: 'ROM',
  bed: 'BED',
  user: 'USR',
  user_profile: 'UPR',
  user_role: 'URO',
  staff_position: 'SPO',
  patient: 'PAT',
  staff_profile: 'STF',
  appointment: 'APT',
  encounter: 'ENC',
  admission: 'ADM',
  invoice: 'INV',
  payment: 'PAY',
  role: 'ROL',
  permission: 'PER',
});

const ROLE_PREFIX_MAP = Object.freeze({
  SUPER_ADMIN: 'SUP',
  TENANT_ADMIN: 'TEN',
  FACILITY_ADMIN: 'FAC',
  HR: 'HRM',
  DOCTOR: 'DOC',
  NURSE: 'NUR',
  LAB_TECH: 'LAB',
  RADIOLOGY_TECH: 'RAD',
  PHARMACIST: 'PHA',
  RECEPTIONIST: 'REC',
  BILLING: 'BIL',
  OPERATIONS: 'OPR',
  AMBULANCE_OPERATOR: 'AMB',
  UNIT_MANAGER: 'UNT',
  WARD_MANAGER: 'WRM',
  ICU_MANAGER: 'ICM',
  THEATRE_MANAGER: 'THM',
  HOUSEKEEPING_MANAGER: 'HKM',
  BIOMED_MANAGER: 'BMM',
  MORTUARY_STAFF: 'MRT',
  MORTUARY_MANAGER: 'MRM',
  PATIENT: 'PAT',
  BIOMED: 'BIO',
  HOUSE_KEEPER: 'HOU',
  OTHER: 'OTH',
});

const FACILITY_SCOPED_ROLES = new Set([
  'DOCTOR',
  'NURSE',
  'LAB_TECH',
  'RADIOLOGY_TECH',
  'PHARMACIST',
  'RECEPTIONIST',
  'OPERATIONS',
  'AMBULANCE_OPERATOR',
  'HR',
  'BIOMED',
  'HOUSE_KEEPER',
  'UNIT_MANAGER',
  'WARD_MANAGER',
  'ICU_MANAGER',
  'THEATRE_MANAGER',
  'HOUSEKEEPING_MANAGER',
  'BIOMED_MANAGER',
  'MORTUARY_STAFF',
  'MORTUARY_MANAGER',
]);

const isUuid = (value) => typeof value === 'string' && UUID_REGEX.test(value);
const isFriendlyId = (value) => typeof value === 'string' && FRIENDLY_ID_REGEX.test(value);

const normalizePrefix = (value) =>
  (String(value || '')
    .replace(/[^a-zA-Z0-9]/g, '')
    .toUpperCase()
    .slice(0, FRIENDLY_ID_PREFIX_LENGTH)
    .padEnd(FRIENDLY_ID_PREFIX_LENGTH, 'X'));

const deriveModelPrefix = (model) => {
  if (!model) return UNKNOWN_MODEL_PREFIX;
  if (MODEL_PREFIX_OVERRIDES[model]) return normalizePrefix(MODEL_PREFIX_OVERRIDES[model]);

  const alphaNumericModelName = String(model).replace(/[^a-zA-Z0-9]/g, '');
  return normalizePrefix(alphaNumericModelName);
};

const formatFriendlyId = (prefix, sequence) => {
  const safePrefix = normalizePrefix(prefix);
  return `${safePrefix}${String(sequence).padStart(DEFAULT_FRIENDLY_ID_PADDING, '0')}`;
};

const resolveRoleIdFromUserRoleData = (data = {}) => {
  if (typeof data.role_id === 'string' && data.role_id) return data.role_id;
  if (typeof data.role?.connect?.id === 'string' && data.role.connect.id) return data.role.connect.id;
  return null;
};

const resolveRoleNameForUserRole = async (prismaClient, data = {}) => {
  if (typeof data.role?.create?.name === 'string' && data.role.create.name) {
    return data.role.create.name;
  }

  const roleId = resolveRoleIdFromUserRoleData(data);
  if (!roleId) return null;

  const role = await prismaClient.role.findUnique({
    where: { id: roleId },
    select: { name: true },
  });

  return role?.name || null;
};

const buildScopeKey = (model, data, roleName, prefix) => {
  if (model === 'user_role' && roleName) {
    if (FACILITY_SCOPED_ROLES.has(roleName) && typeof data.facility_id === 'string' && data.facility_id) {
      return `facility:${data.facility_id}:role:${roleName}:prefix:${prefix}`;
    }
    if (typeof data.tenant_id === 'string' && data.tenant_id) {
      return `tenant:${data.tenant_id}:role:${roleName}:prefix:${prefix}`;
    }
    return `global:role:${roleName}:prefix:${prefix}`;
  }

  if (typeof data.facility_id === 'string' && data.facility_id) {
    return `facility:${data.facility_id}:model:${model}:prefix:${prefix}`;
  }

  if (typeof data.tenant_id === 'string' && data.tenant_id) {
    return `tenant:${data.tenant_id}:model:${model}:prefix:${prefix}`;
  }

  return `global:model:${model}:prefix:${prefix}`;
};

const reserveNextFriendlySequence = async (prismaClient, model, prefix, scopeKey, retryCount = 0) => {
  try {
    const counter = await prismaClient.human_id_counter.upsert({
      where: {
        model_name_prefix_scope_key: {
          model_name: model,
          prefix,
          scope_key: scopeKey,
        },
      },
      create: {
        model_name: model,
        prefix,
        scope_key: scopeKey,
        last_value: 1,
      },
      update: {
        last_value: {
          increment: 1,
        },
      },
      select: {
        last_value: true,
      },
    });

    return counter.last_value;
  } catch (error) {
    if (error?.code === 'P2002' && retryCount < FRIENDLY_ID_COUNTER_RETRIES) {
      return reserveNextFriendlySequence(prismaClient, model, prefix, scopeKey, retryCount + 1);
    }
    throw error;
  }
};

const assignFriendlyIdIfMissing = async (prismaClient, model, data) => {
  if (!data || typeof data !== 'object') return;
  if (SYSTEM_MODELS.has(model)) return;

  if (typeof data.human_friendly_id === 'string' && data.human_friendly_id.trim()) {
    const standardizedInput = data.human_friendly_id.trim().toUpperCase();
    if (isFriendlyId(standardizedInput)) {
      data.human_friendly_id = standardizedInput;
      return;
    }
  }

  let roleName = null;
  if (model === 'user_role') {
    roleName = await resolveRoleNameForUserRole(prismaClient, data);
  }

  const prefix = normalizePrefix(roleName ? ROLE_PREFIX_MAP[roleName] || roleName : deriveModelPrefix(model));
  const scopeKey = buildScopeKey(model, data, roleName, prefix);
  const sequence = await reserveNextFriendlySequence(prismaClient, model, prefix, scopeKey);

  data.human_friendly_id = formatFriendlyId(prefix, sequence);
};

const rewriteHumanFriendlyIdFilters = (whereInput) => {
  if (!whereInput || typeof whereInput !== 'object') return whereInput;

  const where = whereInput;

  if (typeof where.id === 'string' && !isUuid(where.id)) {
    where.human_friendly_id = where.id;
    delete where.id;
  }

  const walkKeys = ['AND', 'OR', 'NOT'];
  for (const key of walkKeys) {
    if (!where[key]) continue;

    if (Array.isArray(where[key])) {
      where[key] = where[key].map((entry) => rewriteHumanFriendlyIdFilters(entry));
      continue;
    }

    where[key] = rewriteHumanFriendlyIdFilters(where[key]);
  }

  return where;
};

const appendFriendlyIdSearchTerm = (whereInput) => {
  if (!whereInput || typeof whereInput !== 'object' || !Array.isArray(whereInput.OR)) {
    return whereInput;
  }

  const where = whereInput;
  const terms = new Set();

  for (const clause of where.OR) {
    if (!clause || typeof clause !== 'object') continue;
    for (const value of Object.values(clause)) {
      if (value && typeof value === 'object' && typeof value.contains === 'string' && value.contains.trim()) {
        terms.add(value.contains.trim());
      }
    }
  }

  for (const term of terms) {
    const exists = where.OR.some(
      (clause) =>
        clause &&
        typeof clause === 'object' &&
        clause.human_friendly_id &&
        typeof clause.human_friendly_id === 'object' &&
        clause.human_friendly_id.contains === term
    );

    if (!exists) {
      where.OR.push({ human_friendly_id: { contains: term } });
    }
  }

  return where;
};

const withHumanFriendlyIdSupport = (prismaClient) =>
  prismaClient.$extends({
    query: {
      $allModels: {
        async create({ model, args, query }) {
          if (!SYSTEM_MODELS.has(model)) {
            await assignFriendlyIdIfMissing(prismaClient, model, args.data);
          }
          return query(args);
        },
        async createMany({ model, args, query }) {
          if (!SYSTEM_MODELS.has(model)) {
            if (Array.isArray(args.data)) {
              for (const entry of args.data) {
                await assignFriendlyIdIfMissing(prismaClient, model, entry);
              }
            } else {
              await assignFriendlyIdIfMissing(prismaClient, model, args.data);
            }
          }
          return query(args);
        },
        async findFirst({ args, query }) {
          args.where = rewriteHumanFriendlyIdFilters(args.where);
          return query(args);
        },
        async findMany({ args, query }) {
          args.where = appendFriendlyIdSearchTerm(rewriteHumanFriendlyIdFilters(args.where));
          return query(args);
        },
        async count({ args, query }) {
          args.where = appendFriendlyIdSearchTerm(rewriteHumanFriendlyIdFilters(args.where));
          return query(args);
        },
      },
    },
  });

const buildPrismaMariaDbUrl = (databaseUrl) => {
  let parsed;
  try {
    parsed = new URL(databaseUrl);
  } catch (err) {
    throw new Error(`Invalid DATABASE_URL format: ${err.message}`);
  }

  // Ensure compatible scheme for the mariadb driver while preserving all existing
  // credentials/options in DATABASE_URL.
  if (parsed.protocol === 'mysql:') {
    parsed.protocol = 'mariadb:';
  }

  // Keep explicit env-based pool sizing authoritative without dropping any other
  // connection options (ssl, charset, etc.) that may already be present.
  parsed.searchParams.set('connectionLimit', String(PRISMA_POOL_CONNECTION_LIMIT));
  parsed.searchParams.set('connectTimeout', String(PRISMA_POOL_CONNECT_TIMEOUT_MS));
  parsed.searchParams.set('acquireTimeout', String(PRISMA_POOL_ACQUIRE_TIMEOUT_MS));
  parsed.searchParams.set(
    'allowPublicKeyRetrieval',
    String(Boolean(PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL))
  );

  return parsed.toString();
};

/**
 * Prisma client singleton wrapper
 * Handles singleton pattern for development (globalThis) and production instances
 * Prevents multiple Prisma client instances in development with hot-reload
 * 
 * Prisma 7.x: Connection URL must be passed via adapter (MariaDB adapter for MySQL)
 */
const globalForPrisma = globalThis;

const isDevelopment = NODE_ENV === 'development';
const tenantGuardMetadata = buildTenantGuardModelMetadata(Prisma);

const adapter = new PrismaMariaDb(buildPrismaMariaDbUrl(DATABASE_URL));

// Prisma 7.x: Pass adapter to PrismaClient constructor
const basePrisma =
  globalForPrisma.basePrisma ||
  new PrismaClient({
    adapter: adapter,
    log: isDevelopment ? ['query', 'error', 'warn'] : ['error'],
  });

if (isDevelopment || NODE_ENV !== 'production') {
  globalForPrisma.basePrisma = basePrisma;
}

const friendlyPrisma = globalForPrisma.friendlyPrisma || withHumanFriendlyIdSupport(basePrisma);

if (isDevelopment || NODE_ENV !== 'production') {
  globalForPrisma.friendlyPrisma = friendlyPrisma;
}

const prisma =
  globalForPrisma.extendedPrisma ||
  withTenantGuard(friendlyPrisma, {
    baseClient: friendlyPrisma,
    modelMetadata: tenantGuardMetadata
  });

if (isDevelopment || NODE_ENV !== 'production') {
  globalForPrisma.extendedPrisma = prisma;
  globalForPrisma.prisma = prisma;
}

// Add query performance tracking per performance.mdc
// Track query performance using Prisma's $on event system
try {
  const { logQueryPerformance } = require('@lib/performance');
  
  basePrisma.$on('query', (e) => {
    // e.query: SQL query string
    // e.params: Query parameters
    // e.duration: Query duration in milliseconds
    // e.target: Model name (e.g., 'user', 'product')
    
    const durationMs = e.duration;
    const model = e.target || 'unknown';
    
    // Determine if query is complex (has joins, unions, subqueries, etc.)
    // Simple heuristic: queries with JOIN, UNION, or nested SELECT are complex
    const query = e.query || '';
    const queryLower = query.toLowerCase();
    const hasJoin = queryLower.includes('join');
    const hasUnion = queryLower.includes('union');
    const hasSubquery = queryLower.includes('(select') || queryLower.includes('( select');
    const isComplex = hasJoin || hasUnion || hasSubquery;
    
    // Extract operation type from query
    // This is a simple heuristic - actual operation is not directly available in query event
    let operation = 'query';
    if (queryLower.startsWith('insert')) {
      operation = 'create';
    } else if (queryLower.startsWith('update')) {
      operation = 'update';
    } else if (queryLower.startsWith('delete')) {
      operation = 'delete';
    } else if (queryLower.includes('select')) {
      if (queryLower.includes('count(')) {
        operation = 'count';
      } else if (queryLower.includes('limit') && queryLower.match(/limit\s+1\b/)) {
        operation = 'findUnique';
      } else {
        operation = 'findMany';
      }
    }
    
    // Log query performance (non-blocking)
    setImmediate(() => {
      logQueryPerformance(operation, model, durationMs, isComplex);
    });
  });
} catch (err) {
  // If performance tracking fails, log warning but don't crash
  // This ensures Prisma client still works even if performance module has issues
  if (isDevelopment) {
    console.warn('Failed to initialize Prisma query performance tracking:', err.message);
  }
}

module.exports = prisma;

