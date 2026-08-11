/**
 * Chart Account service
 *
 * @module modules/chart-account/services
 * @description Business logic layer for chart of accounts operations.
 */

const chartAccountRepository = require('@repositories/chart-account/chart-account.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId
} = require('@lib/billing/identifiers');

const CHART_ACCOUNT_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  parent: { select: { id: true, code: true, name: true, human_friendly_id: true } }
};

const buildEmptyListResult = (page, limit) => ({
  chartAccounts: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1
  }
});

const mapChartAccountForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  const parent = record.parent
    ? {
        id: record.parent.id,
        code: record.parent.code,
        name: record.parent.name,
        display_id: resolvePublicIdentifier(
          record.parent.display_id,
          record.parent.human_friendly_id,
          record.parent.id
        )
      }
    : record.parent;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    tenant_display_id: resolvePublicIdentifier(
      record?.tenant_display_id,
      record?.tenant?.human_friendly_id,
      record?.tenant_id
    ),
    facility_display_id: resolvePublicIdentifier(
      record?.facility_display_id,
      record?.facility?.human_friendly_id,
      record?.facility_id
    ),
    parent_display_id: resolvePublicIdentifier(
      record?.parent_display_id,
      record?.parent?.human_friendly_id,
      record?.parent_id
    ),
    parent
  };
};

const normalizeCreatePayload = async (data = {}) => {
  const payload = {
    ...data,
    tenant_id: await resolveIdentifierForPayload({
      value: data.tenant_id,
      model: 'tenant',
      field: 'tenant_id'
    }),
    facility_id: await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true
    }),
    parent_id: await resolveIdentifierForPayload({
      value: data.parent_id,
      model: 'chart_account',
      field: 'parent_id',
      nullable: true
    }),
    currency: data.currency || 'UGX',
    is_active: data.is_active !== undefined ? data.is_active : true
  };

  if (payload.effective_from) payload.effective_from = new Date(payload.effective_from);

  return payload;
};

const normalizeUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true
    });
  }

  if (Object.prototype.hasOwnProperty.call(data, 'parent_id')) {
    payload.parent_id = await resolveIdentifierForPayload({
      value: data.parent_id,
      model: 'chart_account',
      field: 'parent_id',
      nullable: true
    });
  }

  if (Object.prototype.hasOwnProperty.call(data, 'effective_from') && data.effective_from) {
    payload.effective_from = new Date(data.effective_from);
  }

  if (Object.prototype.hasOwnProperty.call(data, 'effective_from') && data.effective_from === null) {
    payload.effective_from = null;
  }

  return payload;
};

/**
 * List chart accounts with pagination and filtering
 */
const listChartAccounts = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { code: 'asc' };

    const whereClause = {};

    if (filters.tenant_id !== undefined) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant'
      });
      if (tenantId === null) return buildEmptyListResult(page, limit);
      if (tenantId !== undefined) whereClause.tenant_id = tenantId;
    }

    if (filters.facility_id !== undefined) {
      const facilityId = await resolveIdentifierForFilter({
        value: filters.facility_id,
        model: 'facility',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {}
      });
      if (facilityId === null) return buildEmptyListResult(page, limit);
      if (facilityId !== undefined) whereClause.facility_id = facilityId;
    }

    if (filters.parent_id !== undefined) {
      const parentId = await resolveIdentifierForFilter({
        value: filters.parent_id,
        model: 'chart_account',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {}
      });
      if (parentId === null) return buildEmptyListResult(page, limit);
      if (parentId !== undefined) whereClause.parent_id = parentId;
    }

    if (filters.account_type) whereClause.account_type = filters.account_type;
    if (filters.currency) whereClause.currency = filters.currency;
    if (filters.is_active !== undefined) {
      whereClause.is_active = filters.is_active === true || filters.is_active === 'true';
    }

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { code: { contains: search } },
        { name: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } }
      ];
    }

    const [chartAccounts, total] = await Promise.all([
      chartAccountRepository.findMany(whereClause, skip, limit, orderBy, CHART_ACCOUNT_INCLUDE),
      chartAccountRepository.count(whereClause)
    ]);

    return {
      chartAccounts: chartAccounts.map(mapChartAccountForDisplay),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get chart account by ID
 */
const getChartAccountById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'chart_account',
      identifier: id
    });

    const chartAccount = await chartAccountRepository.findById(
      resolvedId,
      CHART_ACCOUNT_INCLUDE
    );

    if (!chartAccount) {
      throw new HttpError('errors.chart_account.not_found', 404);
    }

    return mapChartAccountForDisplay(chartAccount);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new chart account
 */
const createChartAccount = async (data, userId, ipAddress) => {
  try {
    const payload = await normalizeCreatePayload(data);
    const chartAccount = await chartAccountRepository.create(payload);
    const createdRecord = await chartAccountRepository.findById(
      chartAccount.id,
      CHART_ACCOUNT_INCLUDE
    );

    createAuditLog({
      tenant_id: chartAccount.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'chart_account',
      entity_id: chartAccount.id,
      diff: { after: chartAccount },
      ip_address: ipAddress
    }).catch(() => {});

    return mapChartAccountForDisplay(createdRecord || chartAccount);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update chart account
 */
const updateChartAccount = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'chart_account',
      identifier: id
    });

    const before = await chartAccountRepository.findById(resolvedId, CHART_ACCOUNT_INCLUDE);

    if (!before) {
      throw new HttpError('errors.chart_account.not_found', 404);
    }

    if (Object.prototype.hasOwnProperty.call(data, 'parent_id')) {
      const nextParentId = data.parent_id === null || data.parent_id === undefined
        ? data.parent_id
        : await resolveIdentifierForPayload({
            value: data.parent_id,
            model: 'chart_account',
            field: 'parent_id',
            nullable: true
          });
      if (nextParentId && nextParentId === before.id) {
        throw new HttpError('errors.validation.invalid', 400, [{ field: 'parent_id' }]);
      }
    }

    const payload = await normalizeUpdatePayload(data);
    const chartAccount = await chartAccountRepository.update(before.id, payload);
    const updatedRecord = await chartAccountRepository.findById(
      chartAccount.id,
      CHART_ACCOUNT_INCLUDE
    );

    createAuditLog({
      tenant_id: chartAccount.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'chart_account',
      entity_id: chartAccount.id,
      diff: { before, after: chartAccount },
      ip_address: ipAddress
    }).catch(() => {});

    return mapChartAccountForDisplay(updatedRecord || chartAccount);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listChartAccounts,
  getChartAccountById,
  createChartAccount,
  updateChartAccount
};
