/**
 * Posting Rule service
 *
 * @module modules/accounts-workspace/services
 * @description Business logic for `Accounts & Finance → Setup & Controls →
 * Posting Rules`. Tenant/facility scope, status transitions, optimistic
 * versioning, fiscal-period locks, and audit logging are enforced here; the
 * route layer only gates permissions.
 */

const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const repo = require('@repositories/accounts-workspace/posting-rule.repository');
const fiscalPeriodRepo = require('@repositories/accounts-workspace/fiscal-period.repository');

const SECTION_SLUG = 'posting-rules';
const DEFAULT_PRIORITY = 100;

/** Server sort keys the table may request, mapped to Prisma columns. */
const SORT_KEYS = {
  rule_code: 'rule_code',
  rule_name: 'rule_name',
  source_module: 'source_module',
  event_type: 'event_type',
  debit_account_rule: 'debit_account_rule',
  credit_account_rule: 'credit_account_rule',
  tax_rule: 'tax_rule',
  department_rule: 'department_rule',
  cost_centre_rule: 'cost_centre_rule',
  priority: 'priority',
  effective_from: 'effective_from',
  effective_to: 'effective_to',
  version: 'version',
  test_status: 'test_status',
  rule_status: 'status',
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
const VALID_TEST_STATUSES = new Set(['NOT_TESTED', 'PASSED', 'FAILED']);

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
    rule_code: record.rule_code,
    rule_name: record.rule_name,
    source_module: record.source_module,
    event_type: record.event_type,
    debit_account_rule: record.debit_account_rule,
    credit_account_rule: record.credit_account_rule,
    tax_rule: record.tax_rule,
    department_rule: record.department_rule,
    cost_centre_rule: record.cost_centre_rule,
    priority: record.priority,
    effective_from: iso(record.effective_from),
    effective_to: iso(record.effective_to),
    test_status: record.test_status,
    tested_at: iso(record.tested_at),
    rule_status: record.status,
    entity_and_facility:
      facilityName ||
      resolvePublicIdentifier(null, record.facility?.human_friendly_id, null),
    facility_human_friendly_id: resolvePublicIdentifier(
      null,
      record.facility?.human_friendly_id,
      null
    ),
    notes: record.notes,
    reopened_at: iso(record.reopened_at),
    reopened_by: userDisplayName(record.reopened_user),
    version: record.version,
    created_at: iso(record.created_at),
    updated_at: iso(record.updated_at),
    archived_at: iso(record.archived_at),
  };
};

/** Accepts a pre-parsed array or the raw comma-separated work-items string. */
const parseEnumList = (value, allowed) => {
  const entries = Array.isArray(value)
    ? value
    : clean(value)
        .split(',')
        .map((entry) => entry.trim());
  return entries
    .map((entry) => entry.toUpperCase())
    .filter((entry) => allowed.has(entry));
};

const parseTextList = (value) => {
  const entries = Array.isArray(value)
    ? value
    : clean(value)
        .split(',')
        .map((entry) => entry.trim());
  return entries.filter(Boolean);
};

const buildWhere = (scope, filters = {}) => {
  const where = {
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  };

  const statuses = parseEnumList(filters.status, VALID_STATUSES);
  if (statuses.length) {
    where.status = { in: statuses };
  }
  const testStatuses = parseEnumList(filters.test_status, VALID_TEST_STATUSES);
  if (testStatuses.length) {
    where.test_status = { in: testStatuses };
  }
  const eventTypes = parseTextList(filters.event_type).map((entry) =>
    entry.toUpperCase()
  );
  if (eventTypes.length) {
    where.event_type = { in: eventTypes };
  }
  if (clean(filters.source_module)) {
    where.source_module = clean(filters.source_module);
  }
  if (clean(filters.rule_name)) {
    where.rule_name = { contains: clean(filters.rule_name) };
  }

  // Hierarchical department / cost centre picker: any selected node matches.
  const departments = parseTextList(filters.department_rule);
  const costCentres = parseTextList(filters.cost_centre_rule);
  if (departments.length) {
    where.department_rule = { in: departments };
  }
  if (costCentres.length) {
    where.cost_centre_rule = { in: costCentres };
  }

  const priorityMin = Number(filters.priority_min);
  const priorityMax = Number(filters.priority_max);
  if (Number.isFinite(priorityMin) || Number.isFinite(priorityMax)) {
    where.priority = {
      ...(Number.isFinite(priorityMin) ? { gte: priorityMin } : {}),
      ...(Number.isFinite(priorityMax) ? { lte: priorityMax } : {}),
    };
  }

  const from = filters.from ? toDate(filters.from) : null;
  const to = filters.to ? toDate(filters.to) : null;
  if (from || to) {
    // Any rule whose effective window overlaps the requested range. An open
    // end (null) never excludes a row.
    const clauses = [];
    if (to) {
      clauses.push({
        OR: [{ effective_from: { lte: to } }, { effective_from: null }],
      });
    }
    if (from) {
      clauses.push({
        OR: [{ effective_to: { gte: from } }, { effective_to: null }],
      });
    }
    where.AND = [...(where.AND || []), ...clauses];
  }

  const search = clean(filters.search);
  if (search) {
    where.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { rule_code: { contains: search } },
      { rule_name: { contains: search } },
      { source_module: { contains: search } },
      { event_type: { contains: search.toUpperCase() } },
    ];
  }

  return where;
};

const buildOrderBy = (sortBy, order) => {
  const direction = clean(order).toLowerCase() === 'asc' ? 'asc' : 'desc';
  const column = SORT_KEYS[clean(sortBy)];
  if (!column) {
    // Spec default: the business ordering key descending, then the public
    // reference descending.
    return [{ priority: 'desc' }, { rule_code: 'desc' }];
  }
  return [{ [column]: direction }, { rule_code: direction }];
};

const listPostingRules = async (
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
  if (!value) throw new HttpError('errors.accounts.posting_rule.not_found', 404);

  const record = await repo.findFirst({
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    OR: [{ human_friendly_id: value.toUpperCase() }, { id: value }],
  });
  if (!record) {
    throw new HttpError('errors.accounts.posting_rule.not_found', 404);
  }
  return { record, scope };
};

const getPostingRule = async (identifier, filters = {}, user = {}) => {
  assertEnabled();
  const { record } = await findScopedRecord(identifier, filters, user);
  return toPublicRow(record);
};

/**
 * A rule taking effect inside a locked fiscal period would rewrite how already
 * locked history posts. `fiscal_period` stays the owner of the lock state.
 */
const assertEffectiveDateUnlocked = async (scope, effectiveFrom, sourceModule) => {
  if (!effectiveFrom) return;
  const now = new Date();
  const locked = await fiscalPeriodRepo.findFirst(
    {
      tenant_id: scope.tenant_id,
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      status: { not: 'ARCHIVED' },
      lock_date: { not: null, lte: now },
      start_date: { lte: effectiveFrom },
      end_date: { gte: effectiveFrom },
      ...(sourceModule
        ? { module: { in: ['ALL', clean(sourceModule).toUpperCase()] } }
        : {}),
    },
    {}
  );
  if (locked) {
    throw new HttpError('errors.accounts.posting_rule.period_locked', 409, [
      { field: 'effective_from' },
    ]);
  }
};

/**
 * Two rules for the same event and priority whose effective windows overlap
 * make posting non-deterministic.
 */
const assertNoOverlap = async (scope, payload, excludeId = null) => {
  const from = payload.effective_from ?? null;
  const to = payload.effective_to ?? null;
  const overlapping = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      facility_id: scope.facility_id,
      source_module: payload.source_module,
      event_type: payload.event_type,
      priority: payload.priority,
      status: { not: 'ARCHIVED' },
      ...(excludeId ? { NOT: { id: excludeId } } : {}),
      AND: [
        ...(to
          ? [{ OR: [{ effective_from: { lte: to } }, { effective_from: null }] }]
          : []),
        ...(from
          ? [{ OR: [{ effective_to: { gte: from } }, { effective_to: null }] }]
          : []),
      ],
    },
    {}
  );
  if (overlapping) {
    throw new HttpError('errors.accounts.posting_rule.overlapping', 409, [
      { field: 'priority' },
      { field: 'effective_from' },
    ]);
  }
};

const createPostingRule = async (data = {}, user = {}, ipAddress) => {
  assertEnabled();
  const scope = await resolveScope(
    { facility_id: data.facility_id ?? undefined },
    user
  );

  const payload = {
    tenant_id: scope.tenant_id,
    facility_id: scope.facility_id,
    rule_code: clean(data.rule_code).toUpperCase(),
    rule_name: clean(data.rule_name),
    source_module: clean(data.source_module).toUpperCase(),
    event_type: clean(data.event_type).toUpperCase(),
    debit_account_rule: clean(data.debit_account_rule),
    credit_account_rule: clean(data.credit_account_rule),
    tax_rule: data.tax_rule ? clean(data.tax_rule) : null,
    department_rule: data.department_rule ? clean(data.department_rule) : null,
    cost_centre_rule: data.cost_centre_rule
      ? clean(data.cost_centre_rule)
      : null,
    priority: Number.isFinite(Number(data.priority))
      ? Number(data.priority)
      : DEFAULT_PRIORITY,
    effective_from: toDate(data.effective_from),
    effective_to: toDate(data.effective_to),
    notes: data.notes ? clean(data.notes) : null,
    // The server owns the initial status and the test outcome; a client cannot
    // post a rule straight into ACTIVE or claim it already passed.
    status: 'DRAFT',
    test_status: 'NOT_TESTED',
    created_by: clean(user.id) || null,
    updated_by: clean(user.id) || null,
  };

  const duplicate = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      rule_code: payload.rule_code,
    },
    {}
  );
  if (duplicate) {
    throw new HttpError('errors.accounts.posting_rule.duplicate', 409, [
      { field: 'rule_code' },
    ]);
  }
  await assertEffectiveDateUnlocked(
    scope,
    payload.effective_from,
    payload.source_module
  );
  await assertNoOverlap(scope, payload);

  const created = await repo.create(payload);
  const record = await repo.findFirst({ id: created.id });

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'CREATE',
    entity: 'posting_rule',
    entity_id: created.id,
    diff: { after: toPublicRow(record) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(record);
};

const MUTABLE_STATUSES = new Set(['DRAFT', 'ACTIVE']);

/** Fields whose change invalidates the recorded dry-run outcome. */
const POSTING_FIELDS = [
  'source_module',
  'event_type',
  'debit_account_rule',
  'credit_account_rule',
  'tax_rule',
  'department_rule',
  'cost_centre_rule',
];

const updatePostingRule = async (identifier, data = {}, user = {}, ipAddress) => {
  assertEnabled();
  const { record, scope } = await findScopedRecord(identifier, {}, user);

  if (!MUTABLE_STATUSES.has(record.status)) {
    throw new HttpError('errors.accounts.posting_rule.not_editable', 409, [
      { field: 'rule_status', current_status: record.status },
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
  const has = (field) => Object.prototype.hasOwnProperty.call(data, field);
  const assignText = (field, { upper = false, nullable = false } = {}) => {
    if (!has(field)) return;
    const value = clean(data[field]);
    if (nullable && !value) {
      patch[field] = null;
      return;
    }
    patch[field] = upper ? value.toUpperCase() : value;
  };
  const assignDate = (field) => {
    if (has(field)) patch[field] = toDate(data[field]);
  };

  assignText('rule_code', { upper: true });
  assignText('rule_name');
  assignText('source_module', { upper: true });
  assignText('event_type', { upper: true });
  assignText('debit_account_rule');
  assignText('credit_account_rule');
  assignText('tax_rule', { nullable: true });
  assignText('department_rule', { nullable: true });
  assignText('cost_centre_rule', { nullable: true });
  assignText('notes', { nullable: true });
  assignDate('effective_from');
  assignDate('effective_to');
  if (has('priority') && Number.isFinite(Number(data.priority))) {
    patch.priority = Number(data.priority);
  }

  const nextFrom = has('effective_from')
    ? patch.effective_from
    : record.effective_from;
  const nextTo = has('effective_to') ? patch.effective_to : record.effective_to;
  if (nextFrom && nextTo && nextTo < nextFrom) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'effective_to' },
    ]);
  }

  const nextDebit = patch.debit_account_rule ?? record.debit_account_rule;
  const nextCredit = patch.credit_account_rule ?? record.credit_account_rule;
  if (
    clean(nextDebit).toUpperCase() === clean(nextCredit).toUpperCase() &&
    clean(nextDebit)
  ) {
    throw new HttpError(
      'errors.accounts.posting_rule.same_debit_and_credit',
      400,
      [{ field: 'credit_account_rule' }]
    );
  }

  if (patch.rule_code && patch.rule_code !== record.rule_code) {
    const duplicate = await repo.findFirst(
      { tenant_id: scope.tenant_id, rule_code: patch.rule_code },
      {}
    );
    if (duplicate && duplicate.id !== record.id) {
      throw new HttpError('errors.accounts.posting_rule.duplicate', 409, [
        { field: 'rule_code' },
      ]);
    }
  }

  const nextSourceModule = patch.source_module ?? record.source_module;
  await assertEffectiveDateUnlocked(scope, nextFrom, nextSourceModule);
  await assertNoOverlap(
    scope,
    {
      source_module: nextSourceModule,
      event_type: patch.event_type ?? record.event_type,
      priority: patch.priority ?? record.priority,
      effective_from: nextFrom,
      effective_to: nextTo,
    },
    record.id
  );

  // A rule that changed how it posts is no longer covered by its last dry run.
  const postingChanged = POSTING_FIELDS.some(
    (field) => patch[field] !== undefined && patch[field] !== record[field]
  );
  if (postingChanged && record.test_status !== 'NOT_TESTED') {
    patch.test_status = 'NOT_TESTED';
    patch.tested_at = null;
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
    entity: 'posting_rule',
    entity_id: record.id,
    diff: { before: toPublicRow(record), after: toPublicRow(updated) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(updated);
};

/**
 * Apply activate / deactivate / archive / restore.
 *
 * Archive is a soft state change, never a hard delete: posted history keeps
 * resolving the rule that produced it, and the record can be restored.
 */
const applyPostingRuleAction = async (
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
    throw new HttpError('errors.accounts.posting_rule.invalid_transition', 409, [
      { field: 'rule_status', current_status: record.status, target },
    ]);
  }
  if (action === 'restore' && record.status !== 'ARCHIVED') {
    throw new HttpError('errors.accounts.posting_rule.invalid_transition', 409, [
      { field: 'rule_status', current_status: record.status },
    ]);
  }
  // A failing rule would post to the wrong accounts the moment it goes live.
  if (target === 'ACTIVE' && record.test_status === 'FAILED') {
    throw new HttpError('errors.accounts.posting_rule.test_failed', 409, [
      { field: 'test_status' },
    ]);
  }
  if (target === 'ACTIVE') {
    await assertEffectiveDateUnlocked(
      scope,
      record.effective_from,
      record.source_module
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
    entity: 'posting_rule',
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
const countActivePostingRules = async (filters = {}, user = {}) => {
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
  listPostingRules,
  getPostingRule,
  createPostingRule,
  updatePostingRule,
  applyPostingRuleAction,
  countActivePostingRules,
  toPublicRow,
};
