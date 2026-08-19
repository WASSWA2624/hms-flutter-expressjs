/**
 * Payment Methods service
 *
 * @module modules/accounts-workspace/services
 * @description Business logic for `Accounts & Finance → Setup & Controls →
 * Payment Methods`.
 *
 * `method_type` reuses the canonical `PaymentMethodType` taxonomy that
 * `payment.method` already stores; this record configures how each tender
 * behaves (settlement and clearing accounts, fee rule, evidence and approval
 * requirements, effective window, lifecycle) rather than redefining the
 * taxonomy. Recorded payments are never rewritten from here.
 *
 * Tenant/facility scope, status transitions, optimistic versioning, and audit
 * logging are enforced here; the route layer only gates permissions.
 */

const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const repo = require('@repositories/accounts-workspace/payment-method.repository');

const SECTION_SLUG = 'payment-methods';

/** Server sort keys the table may request, mapped to Prisma columns. */
const SORT_KEYS = {
  method_code: 'method_code',
  method_name: 'method_name',
  method_type: 'method_type',
  incoming_and_outgoing: 'direction',
  direction: 'direction',
  provider: 'provider',
  requires_external_reference: 'requires_external_reference',
  requires_approval: 'requires_approval',
  fee_rule: 'fee_rule',
  facility_scope: 'facility_scope',
  effective_from: 'effective_from',
  effective_to: 'effective_to',
  status: 'status',
  created_at: 'created_at',
  updated_at: 'updated_at',
};

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

const VALID_TYPES = new Set([
  'CASH',
  'CREDIT_CARD',
  'DEBIT_CARD',
  'PREPAID_CARD',
  'GIFT_CARD',
  'VOUCHER',
  'BANK_CHECK',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'INSURANCE',
  'OTHER',
]);

const VALID_DIRECTIONS = new Set(['INCOMING', 'OUTGOING', 'BOTH']);

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

/**
 * Resolve a referenced record inside the caller's tenant.
 *
 * Returns `null` for an absent reference and throws when the identifier does
 * not resolve, so a caller can never point a method at an account outside its
 * own tenant.
 */
const resolveReference = async ({ model, identifier, tenantId, field }) => {
  if (identifier === null || identifier === undefined || identifier === '') {
    return null;
  }
  const record = await resolveModelRecordByIdentifier({
    model,
    identifier,
    where: { deleted_at: null, tenant_id: tenantId },
    select: { id: true },
  });
  if (!record) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }
  return record.id;
};

const accountDisplay = (record) => {
  if (!record) return null;
  const code = clean(record.code);
  const name = clean(record.name);
  if (code && name) return `${code} — ${name}`;
  return (
    code || name || resolvePublicIdentifier(null, record.human_friendly_id, null)
  );
};

const iso = (value) => (value ? new Date(value).toISOString() : null);

/**
 * Public row shape. Raw database IDs never leave this function; the client
 * addresses records by `human_friendly_id`.
 */
const toPublicRow = (record) => {
  if (!record) return null;
  return {
    human_friendly_id: resolvePublicIdentifier(
      null,
      record.human_friendly_id,
      null
    ),
    method_code: record.method_code,
    method_name: record.method_name,
    method_type: record.method_type,
    incoming_and_outgoing: record.direction,
    provider: record.provider,
    settlement_account: accountDisplay(record.settlement_account),
    settlement_account_human_friendly_id: resolvePublicIdentifier(
      null,
      record.settlement_account?.human_friendly_id,
      null
    ),
    clearing_account: accountDisplay(record.clearing_account),
    clearing_account_human_friendly_id: resolvePublicIdentifier(
      null,
      record.clearing_account?.human_friendly_id,
      null
    ),
    requires_external_reference: Boolean(record.requires_external_reference),
    requires_approval: Boolean(record.requires_approval),
    fee_rule: record.fee_rule,
    facility_scope:
      record.facility_scope ||
      (record.facility
        ? clean(record.facility.name) ||
          resolvePublicIdentifier(null, record.facility.human_friendly_id, null)
        : null),
    facility_human_friendly_id: resolvePublicIdentifier(
      null,
      record.facility?.human_friendly_id,
      null
    ),
    effective_from: iso(record.effective_from),
    effective_to: iso(record.effective_to),
    status: record.status,
    notes: record.notes,
    version: record.version,
    created_at: iso(record.created_at),
    updated_at: iso(record.updated_at),
    archived_at: iso(record.archived_at),
  };
};

/** Parse a comma-separated multi-select that may already be an array. */
const parseCsv = (value, allowed) => {
  if (Array.isArray(value)) return value;
  return clean(value)
    .split(',')
    .map((entry) => entry.trim().toUpperCase())
    .filter((entry) => allowed.has(entry));
};

const parseBoolean = (value) => {
  if (value === true || value === false) return value;
  const normalized = clean(value).toLowerCase();
  if (normalized === 'true' || normalized === '1') return true;
  if (normalized === 'false' || normalized === '0') return false;
  return undefined;
};

const buildWhere = (scope, filters = {}) => {
  const where = {
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  };

  // The dedicated route pre-parses these into arrays; the shared work-items
  // route forwards the raw comma-separated strings.
  const statuses = parseCsv(filters.status, VALID_STATUSES);
  if (statuses.length) {
    where.status = { in: statuses };
  }
  const types = parseCsv(filters.method_type, VALID_TYPES);
  if (types.length) {
    where.method_type = { in: types };
  }
  const directions = parseCsv(filters.direction, VALID_DIRECTIONS);
  if (directions.length) {
    where.direction = { in: directions };
  }

  if (clean(filters.method_code)) {
    where.method_code = { contains: clean(filters.method_code) };
  }
  if (clean(filters.method_name)) {
    where.method_name = { contains: clean(filters.method_name) };
  }

  const requiresReference = parseBoolean(filters.requires_external_reference);
  if (requiresReference !== undefined) {
    where.requires_external_reference = requiresReference;
  }
  const requiresApproval = parseBoolean(filters.requires_approval);
  if (requiresApproval !== undefined) {
    where.requires_approval = requiresApproval;
  }

  const from = filters.from ? toDate(filters.from) : null;
  const to = filters.to ? toDate(filters.to) : null;
  if (from || to) {
    // Inclusive boundaries: any effective window overlapping the request.
    // A null `effective_to` means "still open", so it always overlaps.
    if (to) where.effective_from = { lte: to };
    if (from) {
      where.OR = [{ effective_to: null }, { effective_to: { gte: from } }];
    }
  }

  const search = clean(filters.search);
  if (search) {
    const searchOr = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { method_code: { contains: search } },
      { method_name: { contains: search } },
      { provider: { contains: search } },
    ];
    // Keep an existing effective-window OR intact by combining with AND.
    if (where.OR) {
      where.AND = [{ OR: where.OR }, { OR: searchOr }];
      delete where.OR;
    } else {
      where.OR = searchOr;
    }
  }

  return where;
};

/**
 * Reference filters resolved to internal ids inside the caller's tenant.
 *
 * Kept separate from [buildWhere] because resolution is asynchronous.
 */
const applyReferenceFilters = async (where, filters = {}, tenantId) => {
  const settlementAccountId = await resolveReference({
    model: 'chart_account',
    identifier: filters.settlement_account_id,
    tenantId,
    field: 'settlement_account_id',
  });
  if (settlementAccountId) where.settlement_account_id = settlementAccountId;

  const clearingAccountId = await resolveReference({
    model: 'chart_account',
    identifier: filters.clearing_account_id,
    tenantId,
    field: 'clearing_account_id',
  });
  if (clearingAccountId) where.clearing_account_id = clearingAccountId;

  return where;
};

const buildOrderBy = (sortBy, order) => {
  const direction = clean(order).toLowerCase() === 'asc' ? 'asc' : 'desc';
  const column = SORT_KEYS[clean(sortBy)];
  if (!column) {
    // Spec default: most relevant business date descending, then reference.
    return [{ effective_from: 'desc' }, { method_code: 'desc' }];
  }
  return [{ [column]: direction }, { method_code: direction }];
};

const listPaymentMethods = async (
  filters = {},
  page = 1,
  limit = 20,
  user = {},
  sortBy,
  order
) => {
  assertEnabled();
  const scope = await resolveScope(filters, user);
  const where = await applyReferenceFilters(
    buildWhere(scope, filters),
    filters,
    scope.tenant_id
  );
  const skip = (page - 1) * limit;

  const [records, total, statusGroups] = await Promise.all([
    repo.findMany(where, skip, limit, buildOrderBy(sortBy, order)),
    repo.count(where),
    repo.groupByStatus(where),
  ]);

  const statusCounts = statusGroups.reduce((acc, row) => {
    acc[row.status] = row._count?._all ?? 0;
    return acc;
  }, {});

  return {
    items: records.map(toPublicRow),
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
    throw new HttpError('errors.accounts.payment_method.not_found', 404);
  }

  const record = await repo.findFirst({
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    OR: [{ human_friendly_id: value.toUpperCase() }, { id: value }],
  });
  if (!record) {
    throw new HttpError('errors.accounts.payment_method.not_found', 404);
  }
  return { record, scope };
};

const getPaymentMethod = async (identifier, filters = {}, user = {}) => {
  assertEnabled();
  const { record } = await findScopedRecord(identifier, filters, user);
  return toPublicRow(record);
};

/** Resolve every account reference on a create/update payload. */
const resolvePayloadReferences = async (data, tenantId) => {
  const resolved = {};
  const fields = ['settlement_account_id', 'clearing_account_id'];
  for (const field of fields) {
    if (!Object.prototype.hasOwnProperty.call(data, field)) continue;
    resolved[field] = await resolveReference({
      model: 'chart_account',
      identifier: data[field],
      tenantId,
      field,
    });
  }
  return resolved;
};

/**
 * A method that clears through a suspense account needs both legs, otherwise
 * settlement can never be reconciled against the clearing balance.
 */
const assertAccountPairing = (settlementAccountId, clearingAccountId) => {
  if (clearingAccountId && !settlementAccountId) {
    throw new HttpError('errors.accounts.payment_method.settlement_required', 400, [
      { field: 'settlement_account_id' },
    ]);
  }
};

const createPaymentMethod = async (data = {}, user = {}, ipAddress) => {
  assertEnabled();
  const scope = await resolveScope(
    { facility_id: data.facility_id ?? undefined },
    user
  );

  const references = await resolvePayloadReferences(data, scope.tenant_id);
  assertAccountPairing(
    references.settlement_account_id,
    references.clearing_account_id
  );

  const payload = {
    tenant_id: scope.tenant_id,
    facility_id: scope.facility_id,
    method_code: clean(data.method_code).toUpperCase(),
    method_name: clean(data.method_name),
    method_type: clean(data.method_type).toUpperCase(),
    direction: (clean(data.direction) || 'INCOMING').toUpperCase(),
    provider: data.provider ? clean(data.provider) : null,
    requires_external_reference: Boolean(data.requires_external_reference),
    requires_approval: Boolean(data.requires_approval),
    fee_rule: data.fee_rule ? clean(data.fee_rule) : null,
    facility_scope: data.facility_scope ? clean(data.facility_scope) : null,
    effective_from: toDate(data.effective_from),
    effective_to: toDate(data.effective_to),
    notes: data.notes ? clean(data.notes) : null,
    ...references,
    // The server owns the initial status; clients cannot post a record
    // straight into ACTIVE.
    status: 'DRAFT',
    created_by: clean(user.id) || null,
    updated_by: clean(user.id) || null,
  };

  if (!VALID_TYPES.has(payload.method_type)) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'method_type' },
    ]);
  }
  if (!VALID_DIRECTIONS.has(payload.direction)) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'direction' },
    ]);
  }

  const duplicate = await repo.findFirst(
    { tenant_id: scope.tenant_id, method_code: payload.method_code },
    {}
  );
  if (duplicate) {
    throw new HttpError('errors.accounts.payment_method.duplicate', 409, [
      { field: 'method_code' },
    ]);
  }

  const created = await repo.create(payload);
  const record = await repo.findFirst({ id: created.id });

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'CREATE',
    entity: 'payment_method',
    entity_id: created.id,
    diff: { after: toPublicRow(record) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(record);
};

const MUTABLE_STATUSES = new Set(['DRAFT', 'ACTIVE']);

const updatePaymentMethod = async (
  identifier,
  data = {},
  user = {},
  ipAddress
) => {
  assertEnabled();
  const { record, scope } = await findScopedRecord(identifier, {}, user);

  if (!MUTABLE_STATUSES.has(record.status)) {
    throw new HttpError('errors.accounts.payment_method.not_editable', 409, [
      { field: 'status', current_status: record.status },
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

  const patch = { updated_by: clean(user.id) || null };
  const assignText = (field, { upper = false, nullable = false } = {}) => {
    if (!Object.prototype.hasOwnProperty.call(data, field)) return;
    const value = clean(data[field]);
    if (nullable && !value) {
      patch[field] = null;
      return;
    }
    patch[field] = upper ? value.toUpperCase() : value;
  };
  const assignDate = (field) => {
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      patch[field] = toDate(data[field]);
    }
  };
  const assignBoolean = (field) => {
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      patch[field] = Boolean(data[field]);
    }
  };

  assignText('method_code', { upper: true });
  assignText('method_name');
  assignText('method_type', { upper: true });
  assignText('direction', { upper: true });
  assignText('provider', { nullable: true });
  assignText('fee_rule', { nullable: true });
  assignText('facility_scope', { nullable: true });
  assignText('notes', { nullable: true });
  assignBoolean('requires_external_reference');
  assignBoolean('requires_approval');
  assignDate('effective_from');
  assignDate('effective_to');
  Object.assign(patch, await resolvePayloadReferences(data, scope.tenant_id));

  if (patch.method_type && !VALID_TYPES.has(patch.method_type)) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'method_type' },
    ]);
  }
  if (patch.direction && !VALID_DIRECTIONS.has(patch.direction)) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'direction' },
    ]);
  }

  assertAccountPairing(
    patch.settlement_account_id === undefined
      ? record.settlement_account_id
      : patch.settlement_account_id,
    patch.clearing_account_id === undefined
      ? record.clearing_account_id
      : patch.clearing_account_id
  );

  const nextFrom =
    patch.effective_from === undefined
      ? record.effective_from
      : patch.effective_from;
  const nextTo =
    patch.effective_to === undefined ? record.effective_to : patch.effective_to;
  if (nextFrom && nextTo && nextTo < nextFrom) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'effective_to' },
    ]);
  }

  if (patch.method_code && patch.method_code !== record.method_code) {
    const duplicate = await repo.findFirst(
      {
        tenant_id: scope.tenant_id,
        method_code: patch.method_code,
        NOT: { id: record.id },
      },
      {}
    );
    if (duplicate) {
      throw new HttpError('errors.accounts.payment_method.duplicate', 409, [
        { field: 'method_code' },
      ]);
    }
  }

  const updated = await repo.updateWithVersion(
    record.id,
    expectedVersion,
    patch
  );
  if (!updated) {
    throw new HttpError('errors.conflict', 409, [
      { field: 'version', current_version: record.version },
    ]);
  }

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'UPDATE',
    entity: 'payment_method',
    entity_id: record.id,
    diff: { before: toPublicRow(record), after: toPublicRow(updated) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(updated);
};

/**
 * Apply activate / deactivate / archive / restore.
 *
 * Archive is a soft state change, never a hard delete: configuration history
 * stays queryable and restorable, and it is refused while recorded payments
 * already used this tender.
 */
const applyPaymentMethodAction = async (
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
      'errors.accounts.payment_method.invalid_transition',
      409,
      [{ field: 'status', current_status: record.status, target }]
    );
  }
  if (action === 'restore' && record.status !== 'ARCHIVED') {
    throw new HttpError(
      'errors.accounts.payment_method.invalid_transition',
      409,
      [{ field: 'status', current_status: record.status }]
    );
  }

  if (action === 'archive') {
    const recorded = await repo.countRecordedPayments({
      tenantId: scope.tenant_id,
      facilityId: record.facility_id,
      methodType: record.method_type,
    });
    if (recorded > 0) {
      throw new HttpError('errors.accounts.payment_method.referenced', 409, [
        { field: 'status', payments: recorded },
      ]);
    }
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

  const patch = {
    status: target,
    updated_by: clean(user.id) || null,
    archived_at: target === 'ARCHIVED' ? new Date() : null,
  };

  const updated = await repo.updateWithVersion(
    record.id,
    expectedVersion,
    patch
  );
  if (!updated) {
    throw new HttpError('errors.conflict', 409, [
      { field: 'version', current_version: record.version },
    ]);
  }

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: ACTION_AUDIT[action],
    entity: 'payment_method',
    entity_id: record.id,
    diff: {
      before: toPublicRow(record),
      after: toPublicRow(updated),
      reason: clean(body.reason) || null,
    },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(updated);
};

/** Unfiltered scope total used by the workspace summary and tab badge. */
const countActivePaymentMethods = async (filters = {}, user = {}) => {
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
  ALLOWED_TRANSITIONS,
  listPaymentMethods,
  getPaymentMethod,
  createPaymentMethod,
  updatePaymentMethod,
  applyPaymentMethodAction,
  countActivePaymentMethods,
  toPublicRow,
};
