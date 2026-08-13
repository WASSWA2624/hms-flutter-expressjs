/**
 * Currency rate service
 *
 * @module modules/accounts-workspace/services
 * @description Business logic for `Accounts & Finance → Setup & Controls →
 * Currencies & Exchange Rates`. Tenant/facility scope, status transitions,
 * base-currency uniqueness, fiscal period locks, optimistic versioning, and
 * audit logging are enforced here; the route layer only gates permissions.
 */

const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const repo = require('@repositories/accounts-workspace/currency-rate.repository');
const fiscalPeriodRepo = require('@repositories/accounts-workspace/fiscal-period.repository');

const SECTION_SLUG = 'currencies-and-exchange-rates';
const DEFAULT_RATE_TYPE = 'SPOT';

/** Server sort keys the table may request, mapped to Prisma columns. */
const SORT_KEYS = {
  currency_code: 'currency_code',
  currency_name: 'currency_name',
  symbol: 'symbol',
  decimal_places: 'decimal_places',
  base_currency: 'is_base_currency',
  rate_type: 'rate_type',
  exchange_rate: 'exchange_rate',
  effective_date: 'effective_date',
  source: 'source',
  buy_rate: 'buy_rate',
  sell_rate: 'sell_rate',
  last_updated_at: 'updated_at',
  currency_status: 'status',
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

const toRate = (value) => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'exchange_rate' },
    ]);
  }
  return parsed;
};

/** Prisma returns Decimal instances; the public contract uses plain numbers. */
const decimalToNumber = (value) =>
  value === null || value === undefined ? null : Number(value);

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
    currency_code: record.currency_code,
    currency_name: record.currency_name,
    symbol: record.symbol,
    decimal_places: record.decimal_places,
    base_currency: Boolean(record.is_base_currency),
    rate_type: record.rate_type,
    exchange_rate: decimalToNumber(record.exchange_rate),
    effective_date: iso(record.effective_date),
    source: record.source,
    buy_rate: decimalToNumber(record.buy_rate),
    sell_rate: decimalToNumber(record.sell_rate),
    last_updated_at: iso(record.updated_at),
    updated_by: userDisplayName(record.updated_user),
    currency_status: record.status,
    entity_and_facility:
      facilityName ||
      resolvePublicIdentifier(null, record.facility?.human_friendly_id, null),
    facility_human_friendly_id: resolvePublicIdentifier(
      null,
      record.facility?.human_friendly_id,
      null
    ),
    notes: record.notes,
    version: record.version,
    created_at: iso(record.created_at),
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

  if (clean(filters.currency_code)) {
    where.currency_code = clean(filters.currency_code).toUpperCase();
  }

  const rateTypes = Array.isArray(filters.rate_type)
    ? filters.rate_type
    : clean(filters.rate_type)
        .split(',')
        .map((entry) => entry.trim().toUpperCase())
        .filter(Boolean);
  if (rateTypes.length) {
    where.rate_type = { in: rateTypes };
  }

  if (filters.base_currency !== undefined && filters.base_currency !== '') {
    where.is_base_currency =
      filters.base_currency === true || filters.base_currency === 'true';
  }

  if (clean(filters.source)) {
    where.source = { contains: clean(filters.source) };
  }

  const from = filters.from ? toDate(filters.from) : null;
  const to = filters.to ? toDate(filters.to) : null;
  if (from || to) {
    // Inclusive boundaries against the rate's effective date.
    where.effective_date = {
      ...(from ? { gte: from } : {}),
      ...(to ? { lte: to } : {}),
    };
  }

  const search = clean(filters.search);
  if (search) {
    where.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { currency_code: { contains: search.toUpperCase() } },
      { currency_name: { contains: search } },
      { source: { contains: search } },
    ];
  }

  return where;
};

const buildOrderBy = (sortBy, order) => {
  const direction = clean(order).toLowerCase() === 'asc' ? 'asc' : 'desc';
  const column = SORT_KEYS[clean(sortBy)];
  if (!column) {
    // Spec default: most relevant business date descending, then reference.
    return [{ effective_date: 'desc' }, { currency_code: 'desc' }];
  }
  return [{ [column]: direction }, { currency_code: direction }];
};

const listCurrencyRates = async (
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
  if (!value) throw new HttpError('errors.accounts.currency_rate.not_found', 404);

  const record = await repo.findFirst({
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    OR: [{ human_friendly_id: value.toUpperCase() }, { id: value }],
  });
  if (!record) {
    throw new HttpError('errors.accounts.currency_rate.not_found', 404);
  }
  return { record, scope };
};

const getCurrencyRate = async (identifier, filters = {}, user = {}) => {
  assertEnabled();
  const { record } = await findScopedRecord(identifier, filters, user);
  return toPublicRow(record);
};

/**
 * A rate dated inside a locked fiscal period would change already-closed
 * translation results, so the mutation is refused.
 */
const assertPeriodNotLocked = async (scope, effectiveDate) => {
  if (!effectiveDate) return;
  const now = new Date();
  const locked = await fiscalPeriodRepo.findFirst(
    {
      tenant_id: scope.tenant_id,
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      status: { not: 'ARCHIVED' },
      start_date: { lte: effectiveDate },
      end_date: { gte: effectiveDate },
      lock_date: { not: null, lte: now },
    },
    {}
  );
  if (locked) {
    throw new HttpError('errors.accounts.currency_rate.period_locked', 409, [
      { field: 'effective_date' },
    ]);
  }
};

/** Exactly one currency in a scope may carry the base flag. */
const assertSingleBaseCurrency = async (scope, currencyCode, excludeId) => {
  const existing = await repo.findFirst(
    {
      tenant_id: scope.tenant_id,
      facility_id: scope.facility_id,
      is_base_currency: true,
      status: { not: 'ARCHIVED' },
      currency_code: { not: currencyCode },
      ...(excludeId ? { NOT: { id: excludeId } } : {}),
    },
    {}
  );
  if (existing) {
    throw new HttpError('errors.accounts.currency_rate.base_exists', 409, [
      { field: 'base_currency', current_base: existing.currency_code },
    ]);
  }
};

const createCurrencyRate = async (data = {}, user = {}, ipAddress) => {
  assertEnabled();
  const scope = await resolveScope(
    { facility_id: data.facility_id ?? undefined },
    user
  );

  const isBase = data.is_base_currency === true;
  const payload = {
    tenant_id: scope.tenant_id,
    facility_id: scope.facility_id,
    currency_code: clean(data.currency_code).toUpperCase(),
    currency_name: clean(data.currency_name),
    symbol: clean(data.symbol),
    decimal_places:
      data.decimal_places === undefined || data.decimal_places === null
        ? 2
        : Number(data.decimal_places),
    is_base_currency: isBase,
    rate_type: (clean(data.rate_type) || DEFAULT_RATE_TYPE).toUpperCase(),
    exchange_rate: isBase ? 1 : toRate(data.exchange_rate),
    effective_date: toDate(data.effective_date),
    source: data.source ? clean(data.source) : null,
    buy_rate: toRate(data.buy_rate),
    sell_rate: toRate(data.sell_rate),
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
      currency_code: payload.currency_code,
      rate_type: payload.rate_type,
      effective_date: payload.effective_date,
    },
    {}
  );
  if (duplicate) {
    throw new HttpError('errors.accounts.currency_rate.duplicate', 409, [
      { field: 'effective_date' },
    ]);
  }
  if (isBase) {
    await assertSingleBaseCurrency(scope, payload.currency_code, null);
  }
  await assertPeriodNotLocked(scope, payload.effective_date);

  const created = await repo.create(payload);
  const record = await repo.findFirst({ id: created.id });

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: 'CREATE',
    entity: 'accounts_currency_rate',
    entity_id: created.id,
    diff: { after: toPublicRow(record) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(record);
};

const MUTABLE_STATUSES = new Set(['DRAFT', 'ACTIVE']);

const updateCurrencyRate = async (
  identifier,
  data = {},
  user = {},
  ipAddress
) => {
  assertEnabled();
  const { record, scope } = await findScopedRecord(identifier, {}, user);

  if (!MUTABLE_STATUSES.has(record.status)) {
    throw new HttpError('errors.accounts.currency_rate.not_editable', 409, [
      { field: 'currency_status', current_status: record.status },
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

  const has = (field) => Object.prototype.hasOwnProperty.call(data, field);
  const patch = { updated_by: clean(user.id) || null };

  if (has('currency_code')) {
    patch.currency_code = clean(data.currency_code).toUpperCase();
  }
  if (has('currency_name')) patch.currency_name = clean(data.currency_name);
  if (has('symbol')) patch.symbol = clean(data.symbol);
  if (has('decimal_places')) {
    patch.decimal_places = Number(data.decimal_places);
  }
  if (has('rate_type')) {
    patch.rate_type = (clean(data.rate_type) || DEFAULT_RATE_TYPE).toUpperCase();
  }
  if (has('effective_date')) patch.effective_date = toDate(data.effective_date);
  if (has('source')) patch.source = data.source ? clean(data.source) : null;
  if (has('buy_rate')) patch.buy_rate = toRate(data.buy_rate);
  if (has('sell_rate')) patch.sell_rate = toRate(data.sell_rate);
  if (has('notes')) patch.notes = data.notes ? clean(data.notes) : null;
  if (has('is_base_currency')) {
    patch.is_base_currency = data.is_base_currency === true;
  }
  if (has('exchange_rate')) patch.exchange_rate = toRate(data.exchange_rate);

  const nextIsBase = patch.is_base_currency ?? record.is_base_currency;
  const nextCode = patch.currency_code ?? record.currency_code;
  const nextEffective = patch.effective_date ?? record.effective_date;
  const nextRateType = patch.rate_type ?? record.rate_type;
  if (nextIsBase) {
    // A base currency is quoted against itself.
    patch.exchange_rate = 1;
    await assertSingleBaseCurrency(scope, nextCode, record.id);
  }

  const nextBuy =
    patch.buy_rate !== undefined
      ? patch.buy_rate
      : decimalToNumber(record.buy_rate);
  const nextSell =
    patch.sell_rate !== undefined
      ? patch.sell_rate
      : decimalToNumber(record.sell_rate);
  if (nextBuy !== null && nextSell !== null && nextBuy > nextSell) {
    throw new HttpError('errors.validation.invalid', 400, [
      { field: 'buy_rate' },
    ]);
  }

  const identityChanged =
    nextCode !== record.currency_code ||
    nextRateType !== record.rate_type ||
    new Date(nextEffective).getTime() !==
      new Date(record.effective_date).getTime();
  if (identityChanged) {
    const duplicate = await repo.findFirst(
      {
        tenant_id: scope.tenant_id,
        facility_id: scope.facility_id,
        currency_code: nextCode,
        rate_type: nextRateType,
        effective_date: nextEffective,
        NOT: { id: record.id },
      },
      {}
    );
    if (duplicate) {
      throw new HttpError('errors.accounts.currency_rate.duplicate', 409, [
        { field: 'effective_date' },
      ]);
    }
  }

  await assertPeriodNotLocked(scope, record.effective_date);
  if (identityChanged) {
    await assertPeriodNotLocked(scope, nextEffective);
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
    entity: 'accounts_currency_rate',
    entity_id: record.id,
    diff: { before: toPublicRow(record), after: toPublicRow(updated) },
    ip_address: ipAddress,
  }).catch(() => {});

  return toPublicRow(updated);
};

/**
 * Apply activate / deactivate / archive / restore.
 *
 * Archive is a soft state change, never a hard delete: historical rates stay
 * queryable and restorable for retrospective translation.
 */
const applyCurrencyRateAction = async (
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
      'errors.accounts.currency_rate.invalid_transition',
      409,
      [{ field: 'currency_status', current_status: record.status, target }]
    );
  }
  if (action === 'restore' && record.status !== 'ARCHIVED') {
    throw new HttpError(
      'errors.accounts.currency_rate.invalid_transition',
      409,
      [{ field: 'currency_status', current_status: record.status }]
    );
  }

  // The active base currency anchors every conversion in scope, so it may not
  // be retired while it still holds the flag.
  if (
    record.is_base_currency &&
    (action === 'deactivate' || action === 'archive')
  ) {
    throw new HttpError('errors.accounts.currency_rate.base_in_use', 409, [
      { field: 'base_currency' },
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

  if (action === 'activate' || action === 'restore') {
    await assertSingleBaseCurrency(scope, record.currency_code, record.id);
  }

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

  createAuditLog({
    tenant_id: scope.tenant_id,
    user_id: user.id,
    action: ACTION_AUDIT[action],
    entity: 'accounts_currency_rate',
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
const countActiveCurrencyRates = async (filters = {}, user = {}) => {
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
  listCurrencyRates,
  getCurrencyRate,
  createCurrencyRate,
  updateCurrencyRate,
  applyCurrencyRateAction,
  countActiveCurrencyRates,
  toPublicRow,
};
