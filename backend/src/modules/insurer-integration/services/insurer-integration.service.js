/**
 * Insurer Integration service
 *
 * @module modules/insurer-integration/services
 * @description Business logic layer for insurer integration operations.
 */

const insurerIntegrationRepository = require('@repositories/insurer-integration/insurer-integration.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const INSURER_INTEGRATION_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  coverage_plan: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      provider_name: true,
    },
  },
  insurance_company: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      code: true,
    },
  },
};

const buildEmptyListResult = (page, limit) => ({
  insurerIntegrations: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

/**
 * Map record for API display — never return raw credentials.
 */
const mapInsurerIntegrationForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  const hasCredentials = Boolean(record.credentials_encrypted);

  return {
    ...record,
    credentials_encrypted: hasCredentials ? '***' : null,
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
    coverage_plan_display_id: resolvePublicIdentifier(
      record?.coverage_plan_display_id,
      record?.coverage_plan?.human_friendly_id,
      record?.coverage_plan_id
    ),
    insurance_company_display_id: resolvePublicIdentifier(
      record?.insurance_company_display_id,
      record?.insurance_company?.human_friendly_id,
      record?.insurance_company_id
    ),
    timeline_at: record?.timeline_at || record?.updated_at || record?.created_at || null,
  };
};

const normalizeCreatePayload = async (data = {}) => ({
  ...data,
  tenant_id: await resolveIdentifierForPayload({
    value: data.tenant_id,
    model: 'tenant',
    field: 'tenant_id',
  }),
  facility_id: await resolveIdentifierForPayload({
    value: data.facility_id,
    model: 'facility',
    field: 'facility_id',
    nullable: true,
  }),
  coverage_plan_id: await resolveIdentifierForPayload({
    value: data.coverage_plan_id,
    model: 'coverage_plan',
    field: 'coverage_plan_id',
    nullable: true,
  }),
  insurance_company_id: await resolveIdentifierForPayload({
    value: data.insurance_company_id,
    model: 'insurance_company',
    field: 'insurance_company_id',
    nullable: true,
  }),
});

const normalizeUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true,
    });
  }

  if (Object.prototype.hasOwnProperty.call(data, 'coverage_plan_id')) {
    payload.coverage_plan_id = await resolveIdentifierForPayload({
      value: data.coverage_plan_id,
      model: 'coverage_plan',
      field: 'coverage_plan_id',
      nullable: true,
    });
  }

  if (Object.prototype.hasOwnProperty.call(data, 'insurance_company_id')) {
    payload.insurance_company_id = await resolveIdentifierForPayload({
      value: data.insurance_company_id,
      model: 'insurance_company',
      field: 'insurance_company_id',
      nullable: true,
    });
  }

  return payload;
};

/**
 * List insurer integrations with pagination and filtering
 */
const listInsurerIntegrations = async (filters, page, limit, sortBy, order) => {
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

    if (filters.facility_id !== undefined) {
      const facilityId = await resolveIdentifierForFilter({
        value: filters.facility_id,
        model: 'facility',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
      });
      if (facilityId === null) return buildEmptyListResult(page, limit);
      if (facilityId !== undefined) whereClause.facility_id = facilityId;
    }

    if (filters.coverage_plan_id !== undefined) {
      const coveragePlanId = await resolveIdentifierForFilter({
        value: filters.coverage_plan_id,
        model: 'coverage_plan',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
      });
      if (coveragePlanId === null) return buildEmptyListResult(page, limit);
      if (coveragePlanId !== undefined) whereClause.coverage_plan_id = coveragePlanId;
    }

    if (filters.insurance_company_id !== undefined) {
      const insuranceCompanyId = await resolveIdentifierForFilter({
        value: filters.insurance_company_id,
        model: 'insurance_company',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
      });
      if (insuranceCompanyId === null) return buildEmptyListResult(page, limit);
      if (insuranceCompanyId !== undefined) {
        whereClause.insurance_company_id = insuranceCompanyId;
      }
    }

    if (filters.adapter_type) whereClause.adapter_type = filters.adapter_type;
    if (filters.is_enabled !== undefined) {
      whereClause.is_enabled = filters.is_enabled === true || filters.is_enabled === 'true';
    }

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { name: { contains: search } },
        { base_url: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } },
      ];
    }

    const [insurerIntegrations, total] = await Promise.all([
      insurerIntegrationRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        INSURER_INTEGRATION_INCLUDE
      ),
      insurerIntegrationRepository.count(whereClause),
    ]);

    return {
      insurerIntegrations: insurerIntegrations.map(mapInsurerIntegrationForDisplay),
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
 * Get insurer integration by ID
 */
const getInsurerIntegrationById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurer_integration',
      identifier: id,
    });

    const insurerIntegration = await insurerIntegrationRepository.findById(
      resolvedId,
      INSURER_INTEGRATION_INCLUDE
    );

    if (!insurerIntegration) {
      throw new HttpError('errors.insurer_integration.not_found', 404);
    }

    return mapInsurerIntegrationForDisplay(insurerIntegration);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new insurer integration
 */
const createInsurerIntegration = async (data, userId, ipAddress) => {
  try {
    const payload = await normalizeCreatePayload(data);
    const insurerIntegration = await insurerIntegrationRepository.create(payload);
    const createdRecord = await insurerIntegrationRepository.findById(
      insurerIntegration.id,
      INSURER_INTEGRATION_INCLUDE
    );

    createAuditLog({
      tenant_id: insurerIntegration.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'insurer_integration',
      entity_id: insurerIntegration.id,
      diff: {
        after: {
          ...insurerIntegration,
          credentials_encrypted: insurerIntegration.credentials_encrypted ? '***' : null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapInsurerIntegrationForDisplay(createdRecord || insurerIntegration);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update insurer integration
 */
const updateInsurerIntegration = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurer_integration',
      identifier: id,
    });

    const before = await insurerIntegrationRepository.findById(
      resolvedId,
      INSURER_INTEGRATION_INCLUDE
    );

    if (!before) {
      throw new HttpError('errors.insurer_integration.not_found', 404);
    }

    const payload = await normalizeUpdatePayload(data);
    const insurerIntegration = await insurerIntegrationRepository.update(before.id, payload);
    const updatedRecord = await insurerIntegrationRepository.findById(
      insurerIntegration.id,
      INSURER_INTEGRATION_INCLUDE
    );

    createAuditLog({
      tenant_id: insurerIntegration.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'insurer_integration',
      entity_id: insurerIntegration.id,
      diff: {
        before: {
          ...before,
          credentials_encrypted: before.credentials_encrypted ? '***' : null,
        },
        after: {
          ...insurerIntegration,
          credentials_encrypted: insurerIntegration.credentials_encrypted ? '***' : null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapInsurerIntegrationForDisplay(updatedRecord || insurerIntegration);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete insurer integration (soft delete)
 */
const deleteInsurerIntegration = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurer_integration',
      identifier: id,
    });

    const before = await insurerIntegrationRepository.findById(
      resolvedId,
      INSURER_INTEGRATION_INCLUDE
    );

    if (!before) {
      throw new HttpError('errors.insurer_integration.not_found', 404);
    }

    await insurerIntegrationRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'insurer_integration',
      entity_id: before.id,
      diff: {
        before: {
          ...before,
          credentials_encrypted: before.credentials_encrypted ? '***' : null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listInsurerIntegrations,
  getInsurerIntegrationById,
  createInsurerIntegration,
  updateInsurerIntegration,
  deleteInsurerIntegration,
};
