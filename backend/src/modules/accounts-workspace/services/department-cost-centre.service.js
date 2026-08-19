/**
 * Departments & Cost Centres service
 *
 * @module modules/accounts-workspace/services
 * @description Business logic for `Accounts & Finance → Setup & Controls →
 * Departments & Cost Centres`.
 *
 * The department record is owned by `modules/department` (tenant/facility
 * setup). This service reads and updates the same rows to maintain the finance
 * projection — cost centre, default posting accounts, ownership, effective
 * window, and lifecycle — instead of creating a second source of truth.
 * `is_active` is mirrored from `status` so every pre-finance consumer (units,
 * wards, staff, rosters, referrals, ABAC policies) keeps working unchanged.
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
const repo = require('@repositories/accounts-workspace/department-cost-centre.repository');

const SECTION_SLUG = 'departments-and-cost-centres';
const DEFAULT_DEPARTMENT_TYPE = 'OTHER';

/** Server sort keys the table may request, mapped to Prisma columns. */
const SORT_KEYS = {
  department_code: 'code',
  department_name: 'name',
  cost_centre_code: 'cost_centre_code',
  cost_centre_name: 'cost_centre_name',
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

const ACTION_AUDIT = {
  activate: 'ACTIVATE',
  deactivate: 'DEACTIVATE',
  archive: 'ARCHIVE',
  restore: 'RESTORE',
};

/** `is_active` mirrors `status` so pre-finance consumers stay correct. */
const isActiveFor = (status) => status === 'ACTIVE';

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
 * not resolve, so a caller can never point a department at a record outside
 * its own tenant.
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

const userDisplayName = (record) => {
  if (!record) return null;
  const first = clean(record.profile?.first_name);
  const last = clean(record.profile?.last_name);
  const full = `${first} ${last}`.trim();
  return full || resolvePublicIdentifier(null, record.human_friendly_id, null);
};

const accountDisplay = (record) => {
  if (!record) return null;
  const code = clean(record.code);
  const name = clean(record.name);
  if (code && name) return `${code} — ${name}`;
  return code || name || resolvePublicIdentifier(null, record.human_friendly_id, null);
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
    department_code: record.code,
    department_name: record.name,
    cost_centre_code: record.cost_centre_code,
    cost_centre_name: record.cost_centre_name,
    parent: record.parent
      ? clean(record.parent.name) ||
        resolvePublicIdentifier(null, record.parent.human_friendly_id, null)
      : null,
    parent_human_friendly_id: resolvePublicIdentifier(
      null,
      record.parent?.human_friendly_id,
      null
    ),
    facility: record.facility
      ? clean(record.facility.name) ||
        resolvePublicIdentifier(null, record.facility.human_friendly_id, null)
      : null,
    facility_human_friendly_id: resolvePublicIdentifier(
      null,
      record.facility?.human_friendly_id,
      null
    ),
    manager: userDisplayName(record.manager),
    manager_human_friendly_id: resolvePublicIdentifier(
      null,
      record.manager?.human_friendly_id,
      null
    ),
    default_revenue_account: accountDisplay(record.default_revenue_account),
    default_revenue_account_human_friendly_id: resolvePublicIdentifier(
      null,
      record.default_revenue_account?.human_friendly_id,
      null
    ),
    default_expense_account: accountDisplay(record.default_expense_account),
    default_expense_account_human_friendly_id: resolvePublicIdentifier(
      null,
      record.default_expense_account?.human_friendly_id,
      null
    ),
    budget_owner: userDisplayName(record.budget_owner),
    budget_owner_human_friendly_id: resolvePublicIdentifier(
      null,
      record.budget_owner?.human_friendly_id,
      null
    ),
    effective_from: iso(record.effective_from),
    effective_to: iso(record.effective_to),
    status: record.status,
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
  if (clean(filters.department_code)) {
    where.code = { contains: clean(filters.department_code) };
  }
  if (clean(filters.department_name)) {
    where.name = { contains: clean(filters.department_name) };
  }
  if (clean(filters.cost_centre_name)) {
    where.cost_centre_name = { contains: clean(filters.cost_centre_name) };
  }

  // Hierarchical department / cost centre picker: one or many cost centres.
  const costCentres = Array.isArray(filters.cost_centre_code)
    ? filters.cost_centre_code
    : clean(filters.cost_centre_code)
        .split(',')
        .map((entry) => entry.trim())
        .filter(Boolean);
  if (costCentres.length) {
    where.cost_centre_code = { in: costCentres };
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
      { code: { contains: search } },
      { name: { contains: search } },
      { cost_centre_code: { contains: search } },
      { cost_centre_name: { contains: search } },
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
  const revenueAccountId = await resolveReference({
    model: 'chart_account',
    identifier: filters.default_revenue_account_id,
    tenantId,
    field: 'default_revenue_account_id',
  });
  if (revenueAccountId) where.default_revenue_account_id = revenueAccountId;

  const expenseAccountId = await resolveReference({
    model: 'chart_account',
    identifier: filters.default_expense_account_id,
    tenantId,
    field: 'default_expense_account_id',
  });
  if (expenseAccountId) where.default_expense_account_id = expenseAccountId;

  const budgetOwnerId = await resolveReference({
    model: 'user',
    identifier: filters.budget_owner_id,
    tenantId,
    field: 'budget_owner_id',
  });
  if (budgetOwnerId) where.budget_owner_id = budgetOwnerId;

  // Owner / assigned user matches either responsibility.
  const ownerId = await resolveReference({
    model: 'user',
    identifier: filters.owner_id,
    tenantId,
    field: 'owner_id',
  });
  if (ownerId) {
    const ownerOr = [{ manager_id: ownerId }, { budget_owner_id: ownerId }];
    if (where.AND) {
      where.AND = [...where.AND, { OR: ownerOr }];
    } else if (where.OR) {
      where.AND = [{ OR: where.OR }, { OR: ownerOr }];
      delete where.OR;
    } else {
      where.OR = ownerOr;
    }
  }

  return where;
};

const buildOrderBy = (sortBy, order) => {
  const direction = clean(order).toLowerCase() === 'asc' ? 'asc' : 'desc';
  const column = SORT_KEYS[clean(sortBy)];
  if (!column) {
    // Spec default: most relevant business date descending, then reference.
    return [{ effective_from: 'desc' }, { code: 'desc' }];
  }
  return [{ [column]: direction }, { code: direction }];
};

const listDepartments = async (
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
  if (!value) throw new HttpError('errors.accounts.department.not_found', 404);

  const record = await repo.findFirst({
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    OR: [{ human_friendly_id: value.toUpperCase() }, { id: value }],
  });
  if (!record) {
    throw new HttpError('errors.accounts.department.not_found', 404);
  }
  return { record, scope };
};

const getDepartment = async (identifier, filters = {}, user = {}) => {
  assertEnabled();
  const { record } = await findScopedRecord(identifier, filters, user);
  return toPublicRow(record);
};

/** Resolve every reference on a create/update payload inside the tenant. */
const resolvePayloadReferences = async (data, tenantId) => {
  const resolved = {};
  const pairs = [
    ['parent_id', 'department'],
    ['manager_id', 'user'],
    ['budget_owner_id', 'user'],
    ['default_revenue_account_id', 'chart_account'],
    ['default_expense_account_id', 'chart_account'],
  ];
  for (const [field, model] of pairs) {
    if (!Object.prototype.hasOwnProperty.call(data, field)) continue;
    resolved[field] = await resolveReference({
      model,
      identifier: data[field],
      tenantId,
      field,
    });
  }
  return resolved;
};

const createDepartment = async (data = {}, user = {}, ipAddress) => {
  assertEnabled();
  const scope = await resolveScope(
    { facility_id: data.facility_id ?? undefined },
    user
  );

  const references = await resolvePayloadReferences(data, scope.tenant_id);

  const payload = {
    tenant_id: scope.tenant_id,
    facility_id: scope.facility_id,
    code: clean(data.department_code),
    name: clean(data.department_name),
    cost_centre_code: clean(data.cost_centre_code),
    cost_centre_name: clean(data.cost_centre_name),
    // The department itself stays owned by tenant/facility setup; finance
    // creates it under the neutral type unless setup already classified it.
    department_type: DEFAULT_DEPARTMENT_TYPE,
    effective_from: toDate(data.effective_from),
    effective_to: toDate(data.effective_to),
    ...references,
    // The server owns the initial status; clients cannot post a record
    // straight into ACTIVE.
    status: 'DRAFT',
    is_active: isActiveFor('DRAFT'),
    updated_by: clean(user.id) || null,
  };

  const duplicate = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      facility_id: scope.facility_id,
      OR: [
        { code: payload.code },
        { cost_centre_code: payload.cost_centre_code },
      ],
    },
    {}
  );
  if (duplicate) {
    throw new HttpError('errors.accounts.department.duplicate', 409, [
      {
        field:
          duplicate.code === payload.code
            ? 'department_code'
            : 'cost_centre_code',
      },
    ]);
  }

  const created = await repo.create(payload);
  const record = await repo.findFirst({ id: created.id });

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'CREATE',
    entity: 'department',
    entity_id: created.id,
    diff: { after: toPublicRow(record) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(record);
};

const MUTABLE_STATUSES = new Set(['DRAFT', 'ACTIVE']);

const updateDepartment = async (identifier, data = {}, user = {}, ipAddress) => {
  assertEnabled();
  const { record, scope } = await findScopedRecord(identifier, {}, user);

  if (!MUTABLE_STATUSES.has(record.status)) {
    throw new HttpError('errors.accounts.department.not_editable', 409, [
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
  const assign = (field, column) => {
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      patch[column] = clean(data[field]);
    }
  };
  const assignDate = (field) => {
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      patch[field] = toDate(data[field]);
    }
  };

  assign('department_code', 'code');
  assign('department_name', 'name');
  assign('cost_centre_code', 'cost_centre_code');
  assign('cost_centre_name', 'cost_centre_name');
  assignDate('effective_from');
  assignDate('effective_to');
  Object.assign(patch, await resolvePayloadReferences(data, scope.tenant_id));

  // A department may never be its own parent, directly or otherwise.
  if (patch.parent_id && patch.parent_id === record.id) {
    throw new HttpError('errors.accounts.department.circular_parent', 409, [
      { field: 'parent_id' },
    ]);
  }

  const nextFrom = patch.effective_from ?? record.effective_from;
  const nextTo =
    patch.effective_to === undefined ? record.effective_to : patch.effective_to;
  if (nextFrom && nextTo && nextTo < nextFrom) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'effective_to' },
    ]);
  }

  const nextCode = patch.code ?? record.code;
  const nextCostCentre = patch.cost_centre_code ?? record.cost_centre_code;
  const duplicate = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      facility_id: record.facility_id,
      NOT: { id: record.id },
      OR: [{ code: nextCode }, { cost_centre_code: nextCostCentre }],
    },
    {}
  );
  if (duplicate) {
    throw new HttpError('errors.accounts.department.duplicate', 409, [
      {
        field:
          duplicate.code === nextCode ? 'department_code' : 'cost_centre_code',
      },
    ]);
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
    action: 'UPDATE',
    entity: 'department',
    entity_id: record.id,
    diff: { before: toPublicRow(record), after: toPublicRow(updated) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(updated);
};

/**
 * Apply activate / deactivate / archive / restore.
 *
 * Archive is a soft state change, never a hard delete: history stays queryable
 * and restorable, and it is refused while live children, units, or wards still
 * reference the department.
 */
const applyDepartmentAction = async (
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
    throw new HttpError('errors.accounts.department.invalid_transition', 409, [
      { field: 'status', current_status: record.status, target },
    ]);
  }
  if (action === 'restore' && record.status !== 'ARCHIVED') {
    throw new HttpError('errors.accounts.department.invalid_transition', 409, [
      { field: 'status', current_status: record.status },
    ]);
  }

  if (action === 'archive') {
    const blocking = await repo.countBlockingReferences(record.id);
    if (blocking.total > 0) {
      throw new HttpError('errors.accounts.department.referenced', 409, [
        {
          field: 'status',
          children: blocking.children,
          units: blocking.units,
          wards: blocking.wards,
        },
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
    // Keep the pre-finance flag in step with the finance lifecycle.
    is_active: isActiveFor(target),
    updated_by: clean(user.id) || null,
    archived_at: target === 'ARCHIVED' ? new Date() : null,
  };

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
    entity: 'department',
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
const countActiveDepartments = async (filters = {}, user = {}) => {
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
  listDepartments,
  getDepartment,
  createDepartment,
  updateDepartment,
  applyDepartmentAction,
  countActiveDepartments,
  toPublicRow,
};
