require('module-alias/register');

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { faker } = require('@faker-js/faker');
const BACKEND_ROOT = path.join(__dirname, '..', '..');

try {
  const moduleAlias = require('module-alias');
  const prismaRuntimePath = path.join(BACKEND_ROOT, 'node_modules', '@prisma', 'client', 'runtime');

  moduleAlias.addAliases({
    '@app': path.join(BACKEND_ROOT, 'src', 'app'),
    '@lib': path.join(BACKEND_ROOT, 'src', 'lib'),
    '@config': path.join(BACKEND_ROOT, 'src', 'config'),
    '@middlewares': path.join(BACKEND_ROOT, 'src', 'middlewares'),
    '@logs': path.join(BACKEND_ROOT, 'logs'),
    '@websockets': path.join(BACKEND_ROOT, 'src', 'websockets'),
    '@modules': path.join(BACKEND_ROOT, 'src', 'modules'),
    '@prisma/client': path.join(BACKEND_ROOT, 'src', 'prisma', 'client.js'),
  });
  moduleAlias.addAlias('@prisma/client/runtime', prismaRuntimePath);
} catch (error) {
  console.error('Failed to register seed runtime aliases:', error);
  process.exit(1);
}

try {
  const { registerAllModuleAliases } = require('@lib/aliases');
  registerAllModuleAliases();
} catch (error) {
  console.warn('Failed to register module-scoped aliases:', error.message);
}

const prisma = require('@prisma/client');
const { hashPassword } = require('@lib/crypto/hashPassword');

const DEFAULT_SEED_PASSWORD = 'Hosspi@2624.';
const DEMO_SEED_PACK = 'hms_demo_v2';
const DEFAULT_RANDOM_SEED = 20260302;
const BASE_TIMESTAMP = Date.UTC(2026, 1, 15, 9, 0, 0);

const AUTO_MANAGED_FIELDS = new Set(['created_at', 'updated_at', 'deleted_at', 'version']);

const PUBLIC_ID_PREFIXES = Object.freeze({
  tenant: 'TEN',
  facility: 'FAC',
  branch: 'BRN',
  department: 'DEP',
  ward: 'WRD',
  room: 'ROM',
  bed: 'BED',
  user: 'USR',
  patient: 'PAT',
  appointment: 'APT',
  encounter: 'ENC',
  admission: 'ADM',
  invoice: 'INV',
  payment: 'PAY',
  refund: 'RFD',
  subscription_plan: 'SPLAN',
  subscription: 'SUB',
  subscription_invoice: 'SINV',
  module: 'MOD',
  module_subscription: 'MSUB',
  license: 'LIC',
  configuration_snapshot: 'CFG',
  conversation: 'CONV',
  message: 'MSG',
  notification: 'NOTI',
  template: 'TPL',
  equipment_registry: 'EQP',
  equipment_work_order: 'EWO',
  unit_management_assignment: 'UMA',
  mortuary_deceased_profile: 'MDP',
  mortuary_case: 'MCS',
  mortuary_storage_unit: 'MSU',
  mortuary_storage_slot: 'MSS',
  mortuary_storage_assignment: 'MSA',
  mortuary_custody_event: 'MCE',
  mortuary_viewing: 'MVI',
  mortuary_post_mortem_request: 'MPR',
  mortuary_release_authorisation: 'MRA',
  mortuary_billable_event: 'MBE',
});

const stripInlineComment = (line) => {
  const commentStart = line.indexOf('//');
  return commentStart === -1 ? line : line.slice(0, commentStart);
};

const deterministicHashHex = (value) =>
  crypto.createHash('sha256').update(String(value || '')).digest('hex');

const deterministicUuid = (value) => {
  const hex = deterministicHashHex(value);
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    `4${hex.slice(13, 16)}`,
    `a${hex.slice(17, 20)}`,
    hex.slice(20, 32),
  ].join('-');
};

const compactObject = (value) =>
  Object.fromEntries(
    Object.entries(value || {}).filter(([, entry]) => entry !== undefined)
  );

const mergeJson = (...values) => {
  const result = {};
  for (const value of values) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) continue;
    Object.assign(result, value);
  }
  return Object.keys(result).length > 0 ? result : null;
};

const parseSchemaMetadata = (schemaPath) => {
  const schema = fs.readFileSync(schemaPath, 'utf8');

  const enumValuesByName = new Map();
  const enumBlocks = [...schema.matchAll(/enum\s+(\w+)\s*\{([\s\S]*?)\n\}/g)];
  for (const [, enumName, body] of enumBlocks) {
    const values = [];
    for (const rawLine of body.split(/\r?\n/)) {
      const line = stripInlineComment(rawLine).trim();
      if (!line || line.startsWith('@')) continue;
      const token = line.match(/^(\w+)/);
      if (token) values.push(token[1]);
    }
    enumValuesByName.set(enumName, values);
  }

  const modelBlocks = [...schema.matchAll(/model\s+(\w+)\s*\{([\s\S]*?)\n\}/g)];
  const modelNames = new Set(modelBlocks.map((entry) => entry[1]));
  const modelsByName = new Map();

  for (const [, modelName, body] of modelBlocks) {
    const fields = [];
    for (const rawLine of body.split(/\r?\n/)) {
      const line = stripInlineComment(rawLine).trim();
      if (!line || line.startsWith('@@') || line.startsWith('@')) continue;

      const fieldMatch = line.match(/^(\w+)\s+([A-Za-z_][A-Za-z0-9_]*(?:\[\])?\??)\s*(.*)$/);
      if (!fieldMatch) continue;

      const [, fieldName, typeToken, attributes = ''] = fieldMatch;
      const isList = typeToken.endsWith('[]');
      const isOptional = typeToken.endsWith('?');
      const baseType = typeToken.replace(/\[\]|\?/g, '');
      const kind = modelNames.has(baseType)
        ? 'object'
        : enumValuesByName.has(baseType)
          ? 'enum'
          : 'scalar';
      const hasDefault = /@default\(/.test(attributes);
      const isUpdatedAt = /@updatedAt\b/.test(attributes);
      const isId = /@id\b/.test(attributes);
      const isUnique = /@unique\b/.test(attributes);
      const maxLengthMatch = attributes.match(/@db\.VarChar\((\d+)\)/i);

      fields.push({
        name: fieldName,
        type: baseType,
        kind,
        isList,
        isOptional,
        hasDefault,
        isUpdatedAt,
        isId,
        isUnique,
        maxLength: maxLengthMatch ? Number(maxLengthMatch[1]) : null,
      });
    }

    modelsByName.set(modelName, {
      name: modelName,
      fields,
      fieldByName: new Map(fields.map((field) => [field.name, field])),
    });
  }

  return { enumValuesByName, modelsByName };
};

const defaultStringValue = (modelName, fieldName, key, maxLength) => {
  const lowerField = String(fieldName || '').toLowerCase();
  const token = deterministicHashHex(`${modelName}:${fieldName}:${key}`).slice(0, 8).toUpperCase();
  let value = `${modelName}_${fieldName}_${token}`;

  if (lowerField.includes('email')) value = `${String(key).replace(/[^a-z0-9]+/gi, '.').toLowerCase()}@demo.com`;
  if (lowerField.includes('phone')) value = `+1555${deterministicHashHex(key).slice(0, 7)}`;
  if (lowerField.includes('slug')) value = String(key).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  if (lowerField.includes('currency')) value = 'USD';
  if (lowerField.includes('code')) value = token;
  if (lowerField.includes('url')) value = `https://demo.hosspi.local/${String(key).toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
  if (lowerField.includes('ip_address')) value = `10.${parseInt(token.slice(0, 2), 16) % 200}.${parseInt(token.slice(2, 4), 16) % 200}.${parseInt(token.slice(4, 6), 16) % 200}`;
  if (lowerField.includes('description')) value = `${modelName} seed record for ${key}`;
  if (maxLength && value.length > maxLength) value = value.slice(0, maxLength);
  return value;
};

const defaultScalarValue = (ctx, modelName, field, key) => {
  if (field.kind === 'enum') {
    const values = ctx.schema.enumValuesByName.get(field.type) || [];
    return values[0];
  }

  switch (field.type) {
    case 'String':
      return defaultStringValue(modelName, field.name, key, field.maxLength);
    case 'Boolean':
      return false;
    case 'Int':
      return 0;
    case 'Float':
    case 'Decimal':
      return 0;
    case 'BigInt':
      return BigInt(0);
    case 'DateTime':
      return ctx.date();
    case 'Json':
      return { seed_pack: DEMO_SEED_PACK, seed_key: key };
    case 'Bytes':
      return Buffer.from(String(key));
    default:
      return undefined;
  }
};

const shouldAutofillField = (field) => {
  if (!field) return false;
  if (AUTO_MANAGED_FIELDS.has(field.name)) return false;
  if (field.isUpdatedAt) return false;
  if (field.isList) return false;
  if (field.kind === 'object') return false;
  if (field.isId) return false;
  return !field.isOptional && !field.hasDefault;
};

const createHumanFriendlyId = (modelName, key, prefix = PUBLIC_ID_PREFIXES[modelName] || 'DEMO') => {
  const normalizedPrefix = String(prefix || 'DEMO')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .slice(0, 8) || 'DEMO';
  return `${normalizedPrefix}-${deterministicHashHex(`${modelName}:${key}`).slice(0, 10).toUpperCase()}`;
};

const prepareModelData = (ctx, modelName, key, data = {}, options = {}) => {
  const meta = ctx.schema.modelsByName.get(modelName);
  if (!meta) {
    throw new Error(`Unknown Prisma model "${modelName}"`);
  }

  const merged = compactObject({ ...data });
  const id = merged.id || deterministicUuid(`${modelName}:${key}`);
  merged.id = id;

  if (
    meta.fieldByName.has('human_friendly_id') &&
    merged.human_friendly_id === undefined &&
    options.disableHumanFriendlyId !== true
  ) {
    merged.human_friendly_id = createHumanFriendlyId(modelName, key, options.publicIdPrefix);
  }

  if (meta.fieldByName.has('extension_json')) {
    merged.extension_json = mergeJson(
      merged.extension_json,
      options.seedMeta === false
        ? null
        : ctx.seedMeta({
            tenant_code: options.tenantCode || merged.tenant_code || null,
            scenario_key: options.scenarioKey || null,
          })
    );
  }

  for (const field of meta.fields) {
    if (merged[field.name] !== undefined) continue;
    if (!shouldAutofillField(field)) continue;
    const fallbackValue = defaultScalarValue(ctx, modelName, field, key);
    if (fallbackValue !== undefined) {
      merged[field.name] = fallbackValue;
    }
  }

  return merged;
};

const createSeedContext = ({
  randomSeed = DEFAULT_RANDOM_SEED,
  recordCount = 0,
} = {}) => {
  const parsedSeed = Number.parseInt(String(randomSeed), 10);
  const safeSeed = Number.isFinite(parsedSeed) ? parsedSeed : DEFAULT_RANDOM_SEED;
  faker.seed(safeSeed);

  const schemaPath = path.join(BACKEND_ROOT, 'prisma', 'schema.prisma');
  const schema = parseSchemaMetadata(schemaPath);
  const cache = new Map();

  const ctx = {
    prisma,
    faker,
    randomSeed: safeSeed,
    recordCount,
    schema,
    cache,
    defaultPassword: DEFAULT_SEED_PASSWORD,
    baseTime: new Date(BASE_TIMESTAMP + (safeSeed % 100000) * 1000),
    id: (scope) => deterministicUuid(scope),
    hash: deterministicHashHex,
    date(dayOffset = 0, minuteOffset = 0) {
      return new Date(
        ctx.baseTime.getTime() +
          dayOffset * 24 * 60 * 60 * 1000 +
          minuteOffset * 60 * 1000
      );
    },
    publicId(modelName, key, prefix) {
      return createHumanFriendlyId(modelName, key, prefix);
    },
    seedMeta({ tenant_code: tenantCode = null, scenario_key: scenarioKey = null } = {}) {
      return compactObject({
        seed_pack: DEMO_SEED_PACK,
        tenant_code: tenantCode || undefined,
        scenario_key: scenarioKey || undefined,
      });
    },
    async passwordHash() {
      if (!cache.has('password_hash')) {
        cache.set('password_hash', await hashPassword(DEFAULT_SEED_PASSWORD));
      }
      return cache.get('password_hash');
    },
    modelHasField(modelName, fieldName) {
      return Boolean(ctx.schema.modelsByName.get(modelName)?.fieldByName.has(fieldName));
    },
    ref(key, value) {
      if (value !== undefined) {
        cache.set(`ref:${key}`, value);
      }
      return cache.get(`ref:${key}`);
    },
    async upsert(modelName, key, data = {}, options = {}) {
      const delegate = prisma[modelName];
      if (!delegate || typeof delegate.upsert !== 'function') {
        throw new Error(`Prisma delegate "${modelName}" is unavailable`);
      }

      const createSource =
        options && Object.prototype.hasOwnProperty.call(options, 'createData')
          ? options.createData
          : data;
      const updateSource =
        options && Object.prototype.hasOwnProperty.call(options, 'updateData')
          ? options.updateData
          : data;

      const createPayload = prepareModelData(ctx, modelName, key, createSource, options);
      const updatePayload = prepareModelData(ctx, modelName, key, updateSource, options);
      const { id } = createPayload;
      delete updatePayload.id;

      const record = await delegate.upsert({
        where: { id },
        create: createPayload,
        update: updatePayload,
      });

      if (options.storeAs) {
        ctx.ref(options.storeAs, record);
      } else {
        ctx.ref(`${modelName}:${key}`, record);
      }

      return record;
    },
  };

  return ctx;
};

module.exports = {
  prisma,
  faker,
  DEFAULT_RANDOM_SEED,
  DEFAULT_SEED_PASSWORD,
  DEMO_SEED_PACK,
  PUBLIC_ID_PREFIXES,
  compactObject,
  createHumanFriendlyId,
  createSeedContext,
  defaultScalarValue,
  deterministicHashHex,
  deterministicUuid,
  mergeJson,
  parseSchemaMetadata,
};
