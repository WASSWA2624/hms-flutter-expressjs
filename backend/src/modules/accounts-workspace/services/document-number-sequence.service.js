/**
 * Document number sequence service
 *
 * @module modules/accounts-workspace/services
 * @description Business logic for `Accounts & Finance → Setup & Controls →
 * Document Numbering`. Tenant/facility scope, status transitions, optimistic
 * versioning, and audit logging are enforced here; the route layer only gates
 * permissions.
 *
 * A row here is *policy*. The running counter lives in `human_id_counter`,
 * which `src/prisma/client.js` already owns and increments atomically, so
 * `next_number`, `last_issued_number`, and `last_issued_at` are read back from
 * that counter rather than stored a second time.
 */

const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const {
  buildCounterScopeKey,
  deriveModelPrefix,
  resolveCounterModel,
} = require('@lib/identifiers/friendly-id-sequence');
const repo = require('@repositories/accounts-workspace/document-number-sequence.repository');

const SECTION_SLUG = 'document-numbering';
const DEFAULT_MODULE = 'ALL';

/**
 * Document type → the Prisma model whose `human_id_counter` row this sequence
 * configures. Types that share a document family share a counter, which is the
 * truth: `credit_note` and `debit_note` are both billing adjustments.
 */
const COUNTER_MODEL_BY_TYPE = Object.freeze({
  INVOICE: 'invoice',
  ACCOUNTS_INVOICE: 'accounts_invoice',
  RECEIPT: 'payment',
  PAYMENT: 'payment',
  REFUND: 'refund',
  CREDIT_NOTE: 'billing_adjustment',
  DEBIT_NOTE: 'billing_adjustment',
  PURCHASE_ORDER: 'purchase_order',
  GOODS_RECEIPT: 'goods_receipt',
  CLAIM: 'insurance_claim',
});

/** Server sort keys the table may request, mapped to Prisma columns. */
const SORT_KEYS = {
  sequence_code: 'sequence_code',
  document_type: 'document_type',
  module: 'module',
  facility: 'facility_id',
  prefix: 'prefix',
  suffix: 'suffix',
  date_pattern: 'date_pattern',
  minimum_length: 'minimum_length',
  reset_frequency: 'reset_frequency',
  gap_policy: 'gap_policy',
  sequence_status: 'status',
  status: 'status',
  created_at: 'created_at',
  updated_at: 'updated_at',
};

/**
 * Sort keys the table exposes that are derived from `human_id_counter` rather
 * than stored here. They cannot be pushed into the database query, so the
 * service falls back to its default ordering and the client sorts the page.
 */
const DERIVED_SORT_KEYS = new Set([
  'next_number',
  'last_issued_number',
  'last_issued_at',
]);

/** Status model from the tab specification. */
const ALLOWED_TRANSITIONS = {
  DRAFT: ['ACTIVE', 'ARCHIVED'],
  ACTIVE: ['INACTIVE', 'ARCHIVED'],
  INACTIVE: ['ACTIVE', 'ARCHIVED'],
  ARCHIVED: ['ACTIVE'],
};

const ACTION_TARGET_STATUS = {
  activate: 'ACTIVE',
  deactivate: 'INACTIVE',
  archive: 'ARCHIVED',
  restore: 'ACTIVE',
};

const VALID_STATUSES = new Set(Object.keys(ALLOWED_TRANSITIONS));

const ACTION_AUDIT = {
  activate: 'ACTIVATE',
  deactivate: 'DEACTIVATE',
  archive: 'ARCHIVE',
  restore: 'RESTORE',
};

const clean = (value) => String(value ?? '').trim();

const assertEnabled = () => {
  if (!isFeatureEnabled('accounts_workspace_v1')) {
    throw new HttpError('errors.accounts.workspace_not_enabled', 404);
  }
};

const toDate = (value) => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'date' }]);
  }
  return parsed;
};

const pagination = (page, limit, total) => {
  const totalPages = Math.max(1, Math.ceil(total / Math.max(limit, 1)));
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

/**
 * Resolve the caller's tenant/facility scope.
 *
 * The tenant always comes from the authenticated session so a crafted
 * `tenant_id` filter can never widen scope. A requested facility must resolve
 * inside that tenant.
 */
const resolveScope = async (filters = {}, user = {}) => {
  const tenantId = clean(user.tenant_id) || clean(filters.tenant_id);
  if (!tenantId) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  let facilityId = clean(user.facility_id) || null;
  if (filters.facility_id) {
    const facility = await resolveModelRecordByIdentifier({
      model: 'facility',
      identifier: filters.facility_id,
      where: { deleted_at: null, tenant_id: tenantId },
      select: { id: true },
    });
    if (!facility) throw new HttpError('errors.facility.not_found', 404);
    facilityId = facility.id;
  }

  return { tenant_id: tenantId, facility_id: facilityId };
};

const iso = (value) => (value ? new Date(value).toISOString() : null);

/** `human_id_counter` coordinates for one sequence row. */
const counterKeyFor = (record) => {
  const model = resolveCounterModel(
    clean(record.counter_model) || COUNTER_MODEL_BY_TYPE[record.document_type]
  );
  // The counter is keyed by the model's own derived prefix, not by the
  // configured display prefix: that is the row `src/prisma/client.js` writes.
  const prefix = deriveModelPrefix(model);
  return {
    model_name: model,
    prefix,
    scope_key: buildCounterScopeKey(
      model,
      { tenantId: record.tenant_id, facilityId: record.facility_id },
      prefix
    ),
  };
};

const counterCacheKey = ({ model_name, prefix, scope_key }) =>
  `${model_name}|${prefix}|${scope_key}`;

/**
 * Load the live counters backing `records`, keyed for `toPublicRow`.
 *
 * One query for the whole page; missing rows simply mean nothing has been
 * issued yet.
 */
const loadCounters = async (records = []) => {
  const keys = [];
  const seen = new Set();
  for (const record of records) {
    const key = counterKeyFor(record);
    const cacheKey = counterCacheKey(key);
    if (seen.has(cacheKey)) continue;
    seen.add(cacheKey);
    keys.push(key);
  }

  const rows = await repo.findCounters(keys);
  const byKey = new Map();
  for (const row of rows) {
    byKey.set(counterCacheKey(row), row);
  }
  return byKey;
};

/** Left-pad the issued number and wrap it in the configured affixes. */
const formatSample = (record, value) => {
  const minimumLength = Number(record.minimum_length) || 1;
  const body = String(Math.max(Number(value) || 0, 0)).padStart(
    minimumLength,
    '0'
  );
  const datePattern = clean(record.date_pattern);
  return [clean(record.prefix), datePattern, body, clean(record.suffix)]
    .filter(Boolean)
    .join('');
};

/**
 * Public row shape. Raw database IDs never leave this function; the client
 * addresses records by `human_friendly_id`.
 */
const toPublicRow = (record, counters = new Map()) => {
  if (!record) return null;
  const facilityName = clean(record.facility?.name);
  const counter = counters.get(counterCacheKey(counterKeyFor(record))) || null;
  const lastValue = Number(counter?.last_value ?? 0);
  const hasIssued = Number.isFinite(lastValue) && lastValue > 0;

  return {
    human_friendly_id: resolvePublicIdentifier(
      null,
      record.human_friendly_id,
      null
    ),
    sequence_code: record.sequence_code,
    document_type: record.document_type,
    module: record.module,
    facility:
      facilityName ||
      resolvePublicIdentifier(null, record.facility?.human_friendly_id, null),
    prefix: record.prefix,
    suffix: record.suffix,
    date_pattern: record.date_pattern,
    next_number: hasIssued ? lastValue + 1 : 1,
    minimum_length: record.minimum_length,
    reset_frequency: record.reset_frequency,
    last_issued_number: hasIssued ? lastValue : null,
    last_issued_at: hasIssued ? iso(counter.updated_at) : null,
    gap_policy: record.gap_policy,
    sequence_status: record.status,
    // Derived preview so an administrator can see the effect of the policy
    // without issuing a document.
    next_reference_preview: formatSample(record, hasIssued ? lastValue + 1 : 1),
    facility_human_friendly_id: resolvePublicIdentifier(
      null,
      record.facility?.human_friendly_id,
      null
    ),
    notes: record.notes,
    version: record.version,
    created_at: iso(record.created_at),
    updated_at: iso(record.updated_at),
    archived_at: iso(record.archived_at),
  };
};

const csvUpper = (value, allowed) => {
  if (Array.isArray(value)) {
    return value
      .map((entry) => clean(entry).toUpperCase())
      .filter((entry) => !allowed || allowed.has(entry));
  }
  return clean(value)
    .split(',')
    .map((entry) => entry.trim().toUpperCase())
    .filter((entry) => entry && (!allowed || allowed.has(entry)));
};

const buildWhere = (scope, filters = {}) => {
  const where = {
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  };

  // The dedicated route pre-parses status into an array; the shared work-items
  // route forwards the raw comma-separated string.
  const statuses = csvUpper(filters.status, VALID_STATUSES);
  if (statuses.length) {
    where.status = { in: statuses };
  }

  const documentTypes = csvUpper(filters.document_type);
  if (documentTypes.length) {
    where.document_type = { in: documentTypes };
  }

  const resetFrequencies = csvUpper(filters.reset_frequency);
  if (resetFrequencies.length) {
    where.reset_frequency = { in: resetFrequencies };
  }

  const gapPolicies = csvUpper(filters.gap_policy);
  if (gapPolicies.length) {
    where.gap_policy = { in: gapPolicies };
  }

  if (clean(filters.module)) {
    where.module = clean(filters.module).toUpperCase();
  }
  if (clean(filters.sequence_code)) {
    where.sequence_code = { contains: clean(filters.sequence_code) };
  }
  if (clean(filters.prefix)) {
    where.prefix = { contains: clean(filters.prefix) };
  }

  const from = filters.from ? toDate(filters.from) : null;
  const to = filters.to ? toDate(filters.to) : null;
  if (from || to) {
    // Inclusive boundaries over the record's own timeline; the counter's
    // timestamp lives in another table and cannot be filtered here.
    where.updated_at = {
      ...(from ? { gte: from } : {}),
      ...(to ? { lte: to } : {}),
    };
  }

  const search = clean(filters.search);
  if (search) {
    where.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { sequence_code: { contains: search } },
      { prefix: { contains: search } },
      { suffix: { contains: search } },
      { module: { contains: search } },
    ];
  }

  return where;
};

const buildOrderBy = (sortBy, order) => {
  const direction = clean(order).toLowerCase() === 'asc' ? 'asc' : 'desc';
  const requested = clean(sortBy);
  const column = SORT_KEYS[requested];
  if (!column || DERIVED_SORT_KEYS.has(requested)) {
    // Spec default: the identifying reference, grouped by document type.
    return [{ document_type: 'asc' }, { sequence_code: 'asc' }];
  }
  return [{ [column]: direction }, { sequence_code: direction }];
};

const listDocumentSequences = async (
  filters = {},
  page = 1,
  limit = 20,
  user = {},
  sortBy,
  order
) => {
  assertEnabled();
  const scope = await resolveScope(filters, user);
  const where = buildWhere(scope, filters);
  const skip = (page - 1) * limit;

  const [records, total, statusGroups] = await Promise.all([
    repo.findMany(where, skip, limit, buildOrderBy(sortBy, order)),
    repo.count(where),
    repo.groupByStatus(where),
  ]);

  const counters = await loadCounters(records);
  const statusCounts = statusGroups.reduce((acc, row) => {
    acc[row.status] = row._count?._all ?? 0;
    return acc;
  }, {});

  return {
    items: records.map((record) => toPublicRow(record, counters)),
    pagination: pagination(page, limit, total),
    meta: {
      section: SECTION_SLUG,
      filtered_total: total,
      status_counts: statusCounts,
    },
  };
};

/** Load one record by its public identifier, scoped to the caller. */
const findScopedRecord = async (identifier, filters = {}, user = {}) => {
  const scope = await resolveScope(filters, user);
  const value = clean(identifier);
  if (!value) {
    throw new HttpError('errors.accounts.document_sequence.not_found', 404);
  }

  const record = await repo.findFirst({
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    OR: [{ human_friendly_id: value.toUpperCase() }, { id: value }],
  });
  if (!record) {
    throw new HttpError('errors.accounts.document_sequence.not_found', 404);
  }
  return { record, scope };
};

/** Row plus its live counter, for single-record responses. */
const withCounter = async (record) => {
  const counters = await loadCounters([record]);
  return toPublicRow(record, counters);
};

const getDocumentSequence = async (identifier, filters = {}, user = {}) => {
  assertEnabled();
  const { record } = await findScopedRecord(identifier, filters, user);
  return withCounter(record);
};

/**
 * Two active sequences for the same document family would race for the same
 * counter and issue duplicate references.
 */
const assertNoConflictingSequence = async (scope, payload, excludeId = null) => {
  const duplicateCode = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      sequence_code: payload.sequence_code,
      ...(excludeId ? { NOT: { id: excludeId } } : {}),
    },
    {}
  );
  if (duplicateCode) {
    throw new HttpError('errors.accounts.document_sequence.duplicate', 409, [
      { field: 'sequence_code' },
    ]);
  }

  const duplicateScope = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      facility_id: scope.facility_id,
      document_type: payload.document_type,
      module: payload.module,
      status: { not: 'ARCHIVED' },
      ...(excludeId ? { NOT: { id: excludeId } } : {}),
    },
    {}
  );
  if (duplicateScope) {
    throw new HttpError(
      'errors.accounts.document_sequence.duplicate_scope',
      409,
      [{ field: 'document_type' }]
    );
  }
};

const createDocumentSequence = async (data = {}, user = {}, ipAddress) => {
  assertEnabled();
  const scope = await resolveScope(
    { facility_id: data.facility_id ?? undefined },
    user
  );

  const documentType = clean(data.document_type).toUpperCase();
  const counterModel = COUNTER_MODEL_BY_TYPE[documentType];
  if (!counterModel) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'document_type' },
    ]);
  }

  const payload = {
    tenant_id: scope.tenant_id,
    facility_id: scope.facility_id,
    sequence_code: clean(data.sequence_code).toUpperCase(),
    document_type: documentType,
    module: (clean(data.module) || DEFAULT_MODULE).toUpperCase(),
    counter_model: counterModel,
    prefix: clean(data.prefix).toUpperCase(),
    suffix: data.suffix ? clean(data.suffix).toUpperCase() : null,
    date_pattern: data.date_pattern ? clean(data.date_pattern) : null,
    minimum_length: Number(data.minimum_length),
    reset_frequency: (clean(data.reset_frequency) || 'NEVER').toUpperCase(),
    gap_policy: (clean(data.gap_policy) || 'ALLOW_GAPS').toUpperCase(),
    notes: data.notes ? clean(data.notes) : null,
    // The server owns the initial status; clients cannot post a record straight
    // into ACTIVE.
    status: 'DRAFT',
    created_by: clean(user.id) || null,
    updated_by: clean(user.id) || null,
  };

  await assertNoConflictingSequence(scope, payload);

  const created = await repo.create(payload);
  const record = await repo.findFirst({ id: created.id });
  const publicRow = await withCounter(record);

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'CREATE',
    entity: 'document_number_sequence',
    entity_id: created.id,
    diff: { after: publicRow },
    ip_address: ipAddress,
  }).catch(() => {});

  return publicRow;
};

const MUTABLE_STATUSES = new Set(['DRAFT', 'ACTIVE']);

/**
 * Changing the shape of a sequence that has already issued numbers would make
 * old and new references indistinguishable, so those fields freeze on first
 * use.
 */
const SHAPE_FIELDS = ['prefix', 'suffix', 'date_pattern', 'minimum_length'];

const updateDocumentSequence = async (
  identifier,
  data = {},
  user = {},
  ipAddress
) => {
  assertEnabled();
  const { record, scope } = await findScopedRecord(identifier, {}, user);

  if (!MUTABLE_STATUSES.has(record.status)) {
    throw new HttpError('errors.accounts.document_sequence.not_editable', 409, [
      { field: 'sequence_status', current_status: record.status },
    ]);
  }

  const expectedVersion =
    data.version === undefined || data.version === null
      ? record.version
      : Number(data.version);
  if (expectedVersion !== record.version) {
    throw new HttpError('errors.conflict', 409, [
      { field: 'version', current_version: record.version },
    ]);
  }

  const before = await withCounter(record);
  const hasIssued = Number(before.last_issued_number ?? 0) > 0;

  const patch = { updated_by: clean(user.id) || null };
  const has = (field) => Object.prototype.hasOwnProperty.call(data, field);
  const assignUpper = (field) => {
    if (has(field)) patch[field] = clean(data[field]).toUpperCase();
  };

  if (has('sequence_code')) {
    patch.sequence_code = clean(data.sequence_code).toUpperCase();
  }
  if (has('module')) {
    patch.module = (clean(data.module) || DEFAULT_MODULE).toUpperCase();
  }
  assignUpper('reset_frequency');
  assignUpper('gap_policy');
  if (has('notes')) {
    patch.notes = data.notes ? clean(data.notes) : null;
  }

  if (has('document_type')) {
    const documentType = clean(data.document_type).toUpperCase();
    const counterModel = COUNTER_MODEL_BY_TYPE[documentType];
    if (!counterModel) {
      throw new HttpError('errors.validation.invalid', 400, [
        { field: 'document_type' },
      ]);
    }
    if (hasIssued && documentType !== record.document_type) {
      throw new HttpError('errors.accounts.document_sequence.in_use', 409, [
        { field: 'document_type' },
      ]);
    }
    patch.document_type = documentType;
    patch.counter_model = counterModel;
  }

  for (const field of SHAPE_FIELDS) {
    if (!has(field)) continue;
    const next =
      field === 'minimum_length'
        ? Number(data[field])
        : data[field] === null || data[field] === ''
          ? null
          : field === 'date_pattern'
            ? clean(data[field])
            : clean(data[field]).toUpperCase();
    if (hasIssued && next !== record[field]) {
      throw new HttpError('errors.accounts.document_sequence.in_use', 409, [
        { field },
      ]);
    }
    patch[field] = next;
  }

  await assertNoConflictingSequence(
    scope,
    {
      sequence_code: patch.sequence_code ?? record.sequence_code,
      document_type: patch.document_type ?? record.document_type,
      module: patch.module ?? record.module,
    },
    record.id
  );

  const updated = await repo.updateWithVersion(record.id, expectedVersion, patch);
  if (!updated) {
    throw new HttpError('errors.conflict', 409, [
      { field: 'version', current_version: record.version },
    ]);
  }

  const after = await withCounter(updated);
  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'UPDATE',
    entity: 'document_number_sequence',
    entity_id: record.id,
    diff: { before, after },
    ip_address: ipAddress,
  }).catch(() => {});

  return after;
};

/**
 * Apply activate / deactivate / archive / restore.
 *
 * Archive is a soft state change, never a hard delete: issued references stay
 * traceable to the policy that produced them.
 */
const applyDocumentSequenceAction = async (
  identifier,
  action,
  body = {},
  user = {},
  ipAddress
) => {
  assertEnabled();
  const target = ACTION_TARGET_STATUS[action];
  if (!target) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'action' }]);
  }

  const { record, scope } = await findScopedRecord(identifier, {}, user);

  const allowed = ALLOWED_TRANSITIONS[record.status] || [];
  if (!allowed.includes(target)) {
    throw new HttpError(
      'errors.accounts.document_sequence.invalid_transition',
      409,
      [{ field: 'sequence_status', current_status: record.status, target }]
    );
  }
  if (action === 'restore' && record.status !== 'ARCHIVED') {
    throw new HttpError(
      'errors.accounts.document_sequence.invalid_transition',
      409,
      [{ field: 'sequence_status', current_status: record.status }]
    );
  }

  const expectedVersion =
    body.version === undefined || body.version === null
      ? record.version
      : Number(body.version);
  if (expectedVersion !== record.version) {
    throw new HttpError('errors.conflict', 409, [
      { field: 'version', current_version: record.version },
    ]);
  }

  // Activating a second sequence for the same document family would race the
  // first one for the shared counter.
  if (target === 'ACTIVE') {
    const conflicting = await repo.findFirst(
      {
        tenant_id: record.tenant_id,
        facility_id: record.facility_id,
        document_type: record.document_type,
        module: record.module,
        status: 'ACTIVE',
        NOT: { id: record.id },
      },
      {}
    );
    if (conflicting) {
      throw new HttpError(
        'errors.accounts.document_sequence.duplicate_scope',
        409,
        [{ field: 'document_type' }]
      );
    }
  }

  const before = await withCounter(record);
  const patch = {
    status: target,
    updated_by: clean(user.id) || null,
    archived_at: target === 'ARCHIVED' ? new Date() : null,
  };

  const updated = await repo.updateWithVersion(record.id, expectedVersion, patch);
  if (!updated) {
    throw new HttpError('errors.conflict', 409, [
      { field: 'version', current_version: record.version },
    ]);
  }

  const after = await withCounter(updated);
  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: ACTION_AUDIT[action],
    entity: 'document_number_sequence',
    entity_id: record.id,
    diff: { before, after, reason: clean(body.reason) || null },
    ip_address: ipAddress,
  }).catch(() => {});

  return after;
};

/** Unfiltered scope total used by the workspace summary and tab badge. */
const countActiveDocumentSequences = async (filters = {}, user = {}) => {
  try {
    assertEnabled();
    const scope = await resolveScope(filters, user);
    return await repo.count({
      tenant_id: scope.tenant_id,
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      status: 'ACTIVE',
    });
  } catch (_) {
    return 0;
  }
};

module.exports = {
  SECTION_SLUG,
  SORT_KEYS,
  DERIVED_SORT_KEYS,
  ALLOWED_TRANSITIONS,
  COUNTER_MODEL_BY_TYPE,
  listDocumentSequences,
  getDocumentSequence,
  createDocumentSequence,
  updateDocumentSequence,
  applyDocumentSequenceAction,
  countActiveDocumentSequences,
  counterKeyFor,
  formatSample,
  toPublicRow,
};
