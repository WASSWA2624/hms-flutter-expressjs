/**
 * Coverage Plan service
 *
 * @module modules/coverage-plan/services
 * @description Business logic layer for coverage plan operations.
 */

const coveragePlanRepository = require('@repositories/coverage-plan/coverage-plan.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const COVERAGE_PLAN_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
};

const buildEmptyListResult = (page, limit) => ({
  coveragePlans: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapCoveragePlanForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    tenant_display_id: resolvePublicIdentifier(
      record?.tenant_display_id,
      record?.tenant?.human_friendly_id,
      record?.tenant_id
    ),
    timeline_at: record?.timeline_at || record?.updated_at || record?.created_at || null,
  };
};

/**
 * List coverage plans with pagination and filtering
 */
const listCoveragePlans = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.tenant_id !== undefined) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant',
      });
      if (tenantId === null) return buildEmptyListResult(page, limit);
      if (tenantId !== undefined) whereClause.tenant_id = tenantId;
    }

    if (filters.provider_name) whereClause.provider_name = { contains: filters.provider_name };
    if (filters.name) whereClause.name = { contains: filters.name };

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { name: { contains: search } },
        { provider_name: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } },
      ];
    }

    const [coveragePlans, total] = await Promise.all([
      coveragePlanRepository.findMany(whereClause, skip, limit, orderBy, COVERAGE_PLAN_INCLUDE),
      coveragePlanRepository.count(whereClause),
    ]);

    return {
      coveragePlans: coveragePlans.map(mapCoveragePlanForDisplay),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get coverage plan by ID
 */
const getCoveragePlanById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'coverage_plan',
      identifier: id,
    });

    const coveragePlan = await coveragePlanRepository.findById(resolvedId, COVERAGE_PLAN_INCLUDE);

    if (!coveragePlan) {
      throw new HttpError('errors.coverage_plan.not_found', 404);
    }

    return mapCoveragePlanForDisplay(coveragePlan);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new coverage plan
 */
const createCoveragePlan = async (data, userId, ipAddress) => {
  try {
    const tenantId = await resolveIdentifierForPayload({
      value: data?.tenant_id,
      field: 'tenant_id',
      model: 'tenant',
    });

    const coveragePlan = await coveragePlanRepository.create({
      ...data,
      tenant_id: tenantId,
    });

    const createdRecord = await coveragePlanRepository.findById(coveragePlan.id, COVERAGE_PLAN_INCLUDE);

    createAuditLog({
      tenant_id: coveragePlan.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'coverage_plan',
      entity_id: coveragePlan.id,
      diff: { after: coveragePlan },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapCoveragePlanForDisplay(createdRecord || coveragePlan);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update coverage plan
 */
const updateCoveragePlan = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'coverage_plan',
      identifier: id,
    });

    const before = await coveragePlanRepository.findById(resolvedId, COVERAGE_PLAN_INCLUDE);

    if (!before) {
      throw new HttpError('errors.coverage_plan.not_found', 404);
    }

    const coveragePlan = await coveragePlanRepository.update(before.id, data);
    const updatedRecord = await coveragePlanRepository.findById(coveragePlan.id, COVERAGE_PLAN_INCLUDE);

    createAuditLog({
      tenant_id: coveragePlan.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'coverage_plan',
      entity_id: coveragePlan.id,
      diff: { before, after: coveragePlan },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapCoveragePlanForDisplay(updatedRecord || coveragePlan);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete coverage plan (soft delete)
 */
const deleteCoveragePlan = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'coverage_plan',
      identifier: id,
    });

    const before = await coveragePlanRepository.findById(resolvedId, COVERAGE_PLAN_INCLUDE);

    if (!before) {
      throw new HttpError('errors.coverage_plan.not_found', 404);
    }

    await coveragePlanRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'coverage_plan',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listCoveragePlans,
  getCoveragePlanById,
  createCoveragePlan,
  updateCoveragePlan,
  deleteCoveragePlan,
};
