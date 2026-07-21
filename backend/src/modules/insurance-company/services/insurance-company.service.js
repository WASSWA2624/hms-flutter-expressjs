/**
 * Insurance Company service
 *
 * @module modules/insurance-company/services
 * @description Business logic layer for insurance company operations.
 */

const insuranceCompanyRepository = require('@repositories/insurance-company/insurance-company.repository');
const coveragePlanRepository = require('@repositories/coverage-plan/coverage-plan.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');

const INSURANCE_COMPANY_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  _count: { select: { schemes: true } }};

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
    timeline_at: record?.timeline_at || record?.updated_at || record?.created_at || null};
};

const buildEmptyListResult = (page, limit) => ({
  insuranceCompanies: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1}});

const mapInsuranceCompanyForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    tenant_display_id: resolvePublicIdentifier(
      record?.tenant_display_id,
      record?.tenant?.human_friendly_id,
      record?.tenant_id
    ),
    timeline_at: record?.timeline_at || record?.updated_at || record?.created_at || null};
};

/**
 * List insurance companies with pagination and filtering
 */
const listInsuranceCompanies = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.tenant_id !== undefined) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant'});
      if (tenantId === null) return buildEmptyListResult(page, limit);
      if (tenantId !== undefined) whereClause.tenant_id = tenantId;
    }

    if (filters.code) whereClause.code = filters.code;
    if (filters.is_active !== undefined) {
      whereClause.is_active = filters.is_active === true || filters.is_active === 'true';
    }

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { name: { contains: search } },
        { code: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } }];
    }

    const [insuranceCompanies, total] = await Promise.all([
      insuranceCompanyRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        INSURANCE_COMPANY_INCLUDE
      ),
      insuranceCompanyRepository.count(whereClause)]);

    return {
      insuranceCompanies: insuranceCompanies.map(mapInsuranceCompanyForDisplay),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1}};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get insurance company by ID
 */
const getInsuranceCompanyById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_company',
      identifier: id});

    const insuranceCompany = await insuranceCompanyRepository.findById(
      resolvedId,
      INSURANCE_COMPANY_INCLUDE
    );

    if (!insuranceCompany) {
      throw new HttpError('errors.insurance_company.not_found', 404);
    }

    return mapInsuranceCompanyForDisplay(insuranceCompany);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * List coverage plans (schemes) for an insurance company
 */
const listInsuranceCompanySchemes = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_company',
      identifier: id});

    const insuranceCompany = await insuranceCompanyRepository.findById(resolvedId);

    if (!insuranceCompany) {
      throw new HttpError('errors.insurance_company.not_found', 404);
    }

    const schemes = await coveragePlanRepository.findMany(
      { insurance_company_id: insuranceCompany.id },
      0,
      1000,
      { created_at: 'desc' },
      { tenant: { select: { id: true, human_friendly_id: true } } }
    );

    return schemes.map(mapCoveragePlanForDisplay);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new insurance company
 */
const createInsuranceCompany = async (data, userId, ipAddress) => {
  try {
    const tenantId = await resolveIdentifierForPayload({
      value: data?.tenant_id,
      field: 'tenant_id',
      model: 'tenant'});

    const insuranceCompany = await insuranceCompanyRepository.create({
      ...data,
      tenant_id: tenantId});

    const createdRecord = await insuranceCompanyRepository.findById(
      insuranceCompany.id,
      INSURANCE_COMPANY_INCLUDE
    );

    createAuditLog({
      tenant_id: insuranceCompany.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'insurance_company',
      entity_id: insuranceCompany.id,
      diff: { after: insuranceCompany },
      ip_address: ipAddress}).catch(() => {});

    return mapInsuranceCompanyForDisplay(createdRecord || insuranceCompany);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update insurance company
 */
const updateInsuranceCompany = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_company',
      identifier: id});

    const before = await insuranceCompanyRepository.findById(resolvedId, INSURANCE_COMPANY_INCLUDE);

    if (!before) {
      throw new HttpError('errors.insurance_company.not_found', 404);
    }

    const insuranceCompany = await insuranceCompanyRepository.update(before.id, data);
    const updatedRecord = await insuranceCompanyRepository.findById(
      insuranceCompany.id,
      INSURANCE_COMPANY_INCLUDE
    );

    createAuditLog({
      tenant_id: insuranceCompany.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'insurance_company',
      entity_id: insuranceCompany.id,
      diff: { before, after: insuranceCompany },
      ip_address: ipAddress}).catch(() => {});

    return mapInsuranceCompanyForDisplay(updatedRecord || insuranceCompany);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete insurance company (soft delete)
 */
const deleteInsuranceCompany = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_company',
      identifier: id});

    const before = await insuranceCompanyRepository.findById(resolvedId, INSURANCE_COMPANY_INCLUDE);

    if (!before) {
      throw new HttpError('errors.insurance_company.not_found', 404);
    }

    await insuranceCompanyRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'insurance_company',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress}).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listInsuranceCompanies,
  getInsuranceCompanyById,
  listInsuranceCompanySchemes,
  createInsuranceCompany,
  updateInsuranceCompany,
  deleteInsuranceCompany};
