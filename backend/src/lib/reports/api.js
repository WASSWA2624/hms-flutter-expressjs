const crypto = require('crypto');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter, resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { REPORT_RESOURCE_BY_PANEL } = require('@lib/reports/constants');

const normalizeString = (value) => String(value || '').trim();
const safeUpper = (value) => normalizeString(value).toUpperCase();

const toDate = (value, field) => {
  if (value === undefined || value === null || value === '') return undefined;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }
  return parsed;
};

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: page * limit < total,
  hasPreviousPage: page > 1,
});

const buildSort = (sortBy, order, fallback = 'updated_at', allowlist = []) => {
  const key = normalizeString(sortBy) || fallback;
  const direction = safeUpper(order) === 'ASC' ? 'asc' : 'desc';
  const safeKey = allowlist.includes(key) ? key : fallback;
  return { [safeKey]: direction };
};

const buildSinceFilter = (since) => {
  const parsed = toDate(since, 'since');
  if (!parsed) return {};
  return { updated_at: { gte: parsed } };
};

const buildDateWindowFilter = ({ from, to, field }) => {
  const fromDate = toDate(from, 'from');
  const toDateValue = toDate(to, 'to');
  if (!fromDate && !toDateValue) return {};

  return {
    [field]: {
      ...(fromDate ? { gte: fromDate } : {}),
      ...(toDateValue ? { lte: toDateValue } : {}),
    },
  };
};

const resolveScopedContext = async (input = {}, user = {}) => {
  const userTenantId = user?.tenant_id || user?.tenantId || null;
  const userFacilityId = user?.facility_id || user?.facilityId || null;
  const userBranchId = user?.branch_id || user?.branchId || null;

  const tenantId = normalizeString(input.tenant_id) || userTenantId || null;
  if (!tenantId) {
    throw new HttpError('errors.auth.scope_mismatch', 403);
  }

  const facilityId = await resolveIdentifierForFilter({
    value: input.facility_id ?? userFacilityId,
    model: 'facility',
    where: { tenant_id: tenantId },
  });

  const branchId = await resolveIdentifierForFilter({
    value: input.branch_id ?? userBranchId,
    model: 'branch',
    where: { tenant_id: tenantId },
  });

  return {
    tenant_id: tenantId,
    facility_id: facilityId || null,
    branch_id: branchId || null,
  };
};

const resolveScopeIdsForList = async ({
  filters = {},
  user = {},
  resource = null,
}) => {
  const scoped = await resolveScopedContext(filters, user);
  const tenantWhere = { tenant_id: scoped.tenant_id };
  const definitionWhere = { ...tenantWhere, deleted_at: null };

  const ownerId = await resolveIdentifierForFilter({
    value: filters.owner_id,
    model: 'user',
    where: tenantWhere,
  });

  const reportDefinitionId = await resolveIdentifierForFilter({
    value: filters.report_definition_id || filters.id,
    model: 'report_definition',
    where: definitionWhere,
  });

  const scheduleId = await resolveIdentifierForFilter({
    value: filters.schedule_id,
    model: 'report_schedule',
    where: definitionWhere,
  });

  const userId = await resolveIdentifierForFilter({
    value: filters.user_id,
    model: 'user',
    where: tenantWhere,
  });

  return {
    ...scoped,
    owner_id: ownerId || null,
    report_definition_id: reportDefinitionId || null,
    schedule_id: scheduleId || null,
    user_id: userId || null,
    resource: resource || REPORT_RESOURCE_BY_PANEL[normalizeString(filters.panel)] || null,
  };
};

const resolvePayloadIdentifier = async ({
  value,
  model,
  field,
  tenant_id,
  nullable = false,
}) =>
  resolveIdentifierForPayload({
    value,
    model,
    field,
    nullable,
    where: tenant_id ? { tenant_id } : {},
  });

const buildSearchWhere = (search, fields = []) => {
  const term = normalizeString(search);
  if (!term || !fields.length) return {};
  return {
    OR: fields.map((field) => ({
      [field]: { contains: term, mode: 'insensitive' },
    })),
  };
};

const ensureVersionMatch = ({ current, expectedVersion, serializer }) => {
  if (expectedVersion === undefined || expectedVersion === null) return;

  const numericExpected = Number(expectedVersion);
  const numericCurrent = Number(current?.version || 1);
  if (!Number.isFinite(numericExpected) || numericExpected < 1) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'version' }]);
  }

  if (numericExpected !== numericCurrent) {
    throw new HttpError('errors.conflict', 409, [
      {
        field: 'version',
        message: 'errors.validation.version_conflict',
        current_version: numericCurrent,
        expected_version: numericExpected,
        current_resource: serializer ? serializer(current) : current,
      },
    ]);
  }
};

const createAuditDiff = (before, after, fields = []) =>
  fields.reduce(
    (acc, field) => {
      acc.before[field] = before?.[field] ?? null;
      acc.after[field] = after?.[field] ?? null;
      return acc;
    },
    { before: {}, after: {} }
  );

const createScopeHash = (value) =>
  crypto.createHash('sha1').update(JSON.stringify(value || {})).digest('hex');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

module.exports = {
  buildDateWindowFilter,
  buildPagination,
  buildSearchWhere,
  buildSinceFilter,
  buildSort,
  createAuditDiff,
  createScopeHash,
  ensureVersionMatch,
  normalizeString,
  resolvePayloadIdentifier,
  resolveScopeIdsForList,
  resolveScopedContext,
  safePublicId,
  safeUpper,
  toDate,
};
