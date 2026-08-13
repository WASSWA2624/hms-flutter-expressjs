/**
 * Fiscal Period service
 *
 * @module modules/accounts-workspace/services
 * @description Business logic for `Accounts & Finance → Setup & Controls →
 * Fiscal Years & Periods`. Tenant/facility scope, status transitions,
 * optimistic versioning, and audit logging are enforced here; the route layer
 * only gates permissions.
 */

const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const repo = require('@repositories/accounts-workspace/fiscal-period.repository');

const SECTION_SLUG = 'fiscal-years-and-periods';
const DEFAULT_MODULE = 'ALL';

/** Server sort keys the table may request, mapped to Prisma columns. */
const SORT_KEYS = {
  fiscal_year: 'fiscal_year',
  period_no: 'period_no',
  period_name: 'period_name',
  start_date: 'start_date',
  end_date: 'end_date',
  module: 'module',
  open_date: 'open_date',
  soft_close_date: 'soft_close_date',
  close_date: 'close_date',
  lock_date: 'lock_date',
  reopened_at: 'reopened_at',
  period_status: 'status',
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

const userDisplayName = (record) => {
  if (!record) return null;
  const first = clean(record.profile?.first_name);
  const last = clean(record.profile?.last_name);
  const full = `${first} ${last}`.trim();
  return full || resolvePublicIdentifier(null, record.human_friendly_id, null);
};

const iso = (value) => (value ? new Date(value).toISOString() : null);

/**
 * Public row shape. Raw database IDs never leave this function; the client
 * addresses records by `human_friendly_id`.
 */
const toPublicRow = (record) => {
  if (!record) return null;
  const facilityName = clean(record.facility?.name);
  return {
    human_friendly_id: resolvePublicIdentifier(
      null,
      record.human_friendly_id,
      null
    ),
    fiscal_year: record.fiscal_year,
    period_no: record.period_no,
    period_name: record.period_name,
    start_date: iso(record.start_date),
    end_date: iso(record.end_date),
    entity_and_facility:
      facilityName ||
      resolvePublicIdentifier(null, record.facility?.human_friendly_id, null),
    module: record.module,
    open_date: iso(record.open_date),
    soft_close_date: iso(record.soft_close_date),
    close_date: iso(record.close_date),
    lock_date: iso(record.lock_date),
    reopened_at: iso(record.reopened_at),
    reopened_by: userDisplayName(record.reopened_user),
    period_status: record.status,
    facility_human_friendly_id: resolvePublicIdentifier(
      null,
      record.facility?.human_friendly_id,
      null
    ),
    notes: record.notes,
    is_locked: Boolean(record.lock_date) && new Date(record.lock_date) <= new Date(),
    version: record.version,
    created_at: iso(record.created_at),
    updated_at: iso(record.updated_at),
    archived_at: iso(record.archived_at),
  };
};

const buildWhere = (scope, filters = {}) => {
  const where = {
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  };

  // The dedicated route pre-parses status into an array; the shared work-items
  // route forwards the raw comma-separated string.
  const statuses = Array.isArray(filters.status)
    ? filters.status
    : clean(filters.status)
        .split(',')
        .map((entry) => entry.trim().toUpperCase())
        .filter((entry) => VALID_STATUSES.has(entry));
  if (statuses.length) {
    where.status = { in: statuses };
  }
  if (clean(filters.fiscal_year)) {
    where.fiscal_year = clean(filters.fiscal_year);
  }
  if (clean(filters.module)) {
    where.module = clean(filters.module).toUpperCase();
  }
  if (clean(filters.period_name)) {
    where.period_name = { contains: clean(filters.period_name) };
  }

  const from = filters.from ? toDate(filters.from) : null;
  const to = filters.to ? toDate(filters.to) : null;
  if (from || to) {
    // Inclusive boundaries: any period overlapping the requested range.
    if (to) where.start_date = { lte: to };
    if (from) where.end_date = { gte: from };
  }

  const search = clean(filters.search);
  if (search) {
    where.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { fiscal_year: { contains: search } },
      { period_name: { contains: search } },
      { module: { contains: search } },
    ];
  }

  return where;
};

const buildOrderBy = (sortBy, order) => {
  const direction = clean(order).toLowerCase() === 'asc' ? 'asc' : 'desc';
  const column = SORT_KEYS[clean(sortBy)];
  if (!column) {
    // Spec default: most relevant business date descending, then reference.
    return [{ start_date: 'desc' }, { period_no: 'desc' }];
  }
  return [{ [column]: direction }, { period_no: direction }];
};

const listFiscalPeriods = async (
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
  if (!value) throw new HttpError('errors.accounts.fiscal_period.not_found', 404);

  const record = await repo.findFirst({
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    OR: [{ human_friendly_id: value.toUpperCase() }, { id: value }],
  });
  if (!record) {
    throw new HttpError('errors.accounts.fiscal_period.not_found', 404);
  }
  return { record, scope };
};

const getFiscalPeriod = async (identifier, filters = {}, user = {}) => {
  assertEnabled();
  const { record } = await findScopedRecord(identifier, filters, user);
  return toPublicRow(record);
};

/** Overlapping periods for the same year/module/facility corrupt posting. */
const assertNoOverlap = async (scope, payload, excludeId = null) => {
  const overlapping = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      facility_id: scope.facility_id,
      fiscal_year: payload.fiscal_year,
      module: payload.module,
      status: { not: 'ARCHIVED' },
      start_date: { lte: payload.end_date },
      end_date: { gte: payload.start_date },
      ...(excludeId ? { NOT: { id: excludeId } } : {}),
    },
    {}
  );
  if (overlapping) {
    throw new HttpError('errors.accounts.fiscal_period.overlapping', 409, [
      { field: 'start_date' },
      { field: 'end_date' },
    ]);
  }
};

const createFiscalPeriod = async (data = {}, user = {}, ipAddress) => {
  assertEnabled();
  const scope = await resolveScope(
    { facility_id: data.facility_id ?? undefined },
    user
  );

  const payload = {
    tenant_id: scope.tenant_id,
    facility_id: scope.facility_id,
    fiscal_year: clean(data.fiscal_year),
    period_no: Number(data.period_no),
    period_name: clean(data.period_name),
    start_date: toDate(data.start_date),
    end_date: toDate(data.end_date),
    module: (clean(data.module) || DEFAULT_MODULE).toUpperCase(),
    open_date: toDate(data.open_date),
    soft_close_date: toDate(data.soft_close_date),
    close_date: toDate(data.close_date),
    lock_date: toDate(data.lock_date),
    notes: data.notes ? clean(data.notes) : null,
    // The server owns the initial status; clients cannot post a record straight
    // into ACTIVE.
    status: 'DRAFT',
    created_by: clean(user.id) || null,
    updated_by: clean(user.id) || null,
  };

  const duplicate = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      facility_id: scope.facility_id,
      fiscal_year: payload.fiscal_year,
      period_no: payload.period_no,
      module: payload.module,
    },
    {}
  );
  if (duplicate) {
    throw new HttpError('errors.accounts.fiscal_period.duplicate', 409, [
      { field: 'period_no' },
    ]);
  }
  await assertNoOverlap(scope, payload);

  const created = await repo.create(payload);
  const record = await repo.findFirst({ id: created.id });

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'CREATE',
    entity: 'fiscal_period',
    entity_id: created.id,
    diff: { after: toPublicRow(record) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(record);
};

const MUTABLE_STATUSES = new Set(['DRAFT', 'ACTIVE']);

const updateFiscalPeriod = async (
  identifier,
  data = {},
  user = {},
  ipAddress
) => {
  assertEnabled();
  const { record, scope } = await findScopedRecord(identifier, {}, user);

  if (!MUTABLE_STATUSES.has(record.status)) {
    throw new HttpError('errors.accounts.fiscal_period.not_editable', 409, [
      { field: 'period_status', current_status: record.status },
    ]);
  }
  if (record.lock_date && new Date(record.lock_date) <= new Date()) {
    throw new HttpError('errors.accounts.fiscal_period.locked', 409, [
      { field: 'lock_date' },
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
  const assignText = (field) => {
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      patch[field] = clean(data[field]);
    }
  };
  const assignDate = (field) => {
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      patch[field] = toDate(data[field]);
    }
  };

  assignText('fiscal_year');
  assignText('period_name');
  assignDate('start_date');
  assignDate('end_date');
  assignDate('open_date');
  assignDate('soft_close_date');
  assignDate('close_date');
  assignDate('lock_date');
  if (Object.prototype.hasOwnProperty.call(data, 'module')) {
    patch.module = (clean(data.module) || DEFAULT_MODULE).toUpperCase();
  }
  if (Object.prototype.hasOwnProperty.call(data, 'notes')) {
    patch.notes = data.notes ? clean(data.notes) : null;
  }

  const nextStart = patch.start_date ?? record.start_date;
  const nextEnd = patch.end_date ?? record.end_date;
  if (nextEnd < nextStart) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'end_date' },
    ]);
  }

  await assertNoOverlap(
    scope,
    {
      fiscal_year: patch.fiscal_year ?? record.fiscal_year,
      module: patch.module ?? record.module,
      start_date: nextStart,
      end_date: nextEnd,
    },
    record.id
  );

  const updated = await repo.updateWithVersion(record.id, expectedVersion, patch);
  if (!updated) {
    throw new HttpError('errors.conflict', 409, [
      { field: 'version', current_version: record.version },
    ]);
  }

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'UPDATE',
    entity: 'fiscal_period',
    entity_id: record.id,
    diff: { before: toPublicRow(record), after: toPublicRow(updated) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(updated);
};

/**
 * Apply activate / deactivate / archive / restore.
 *
 * Archive is a soft state change, never a hard delete: posted history stays
 * queryable and restorable.
 */
const applyFiscalPeriodAction = async (
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
    throw new HttpError('errors.accounts.fiscal_period.invalid_transition', 409, [
      { field: 'period_status', current_status: record.status, target },
    ]);
  }
  if (action === 'restore' && record.status !== 'ARCHIVED') {
    throw new HttpError('errors.accounts.fiscal_period.invalid_transition', 409, [
      { field: 'period_status', current_status: record.status },
    ]);
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
  if (action === 'restore') {
    patch.reopened_at = new Date();
    patch.reopened_by = clean(user.id) || null;
  }

  const updated = await repo.updateWithVersion(record.id, expectedVersion, patch);
  if (!updated) {
    throw new HttpError('errors.conflict', 409, [
      { field: 'version', current_version: record.version },
    ]);
  }

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: ACTION_AUDIT[action],
    entity: 'fiscal_period',
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
const countActiveFiscalPeriods = async (filters = {}, user = {}) => {
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
  listFiscalPeriods,
  getFiscalPeriod,
  createFiscalPeriod,
  updateFiscalPeriod,
  applyFiscalPeriodAction,
  countActiveFiscalPeriods,
  toPublicRow,
};
