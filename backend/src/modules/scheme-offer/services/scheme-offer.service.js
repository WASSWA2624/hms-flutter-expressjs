/**
 * Scheme Offer service
 *
 * @module modules/scheme-offer/services
 * @description Business logic layer for scheme offer operations.
 */

const schemeOfferRepository = require('@repositories/scheme-offer/scheme-offer.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');

const SCHEME_OFFER_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  coverage_plan: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      insurance_company_id: true,
      coverage_percentage: true,
      default_copay_type: true,
      default_copay_value: true}}};

const buildEmptyListResult = (page, limit) => ({
  schemeOffers: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1}});

const mapSchemeOfferForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    tenant_display_id: resolvePublicIdentifier(
      record?.tenant_display_id,
      record?.tenant?.human_friendly_id,
      record?.tenant_id
    ),
    coverage_plan_display_id: resolvePublicIdentifier(
      record?.coverage_plan_display_id,
      record?.coverage_plan?.human_friendly_id,
      record?.coverage_plan_id
    ),
    timeline_at: record?.timeline_at || record?.effective_from || record?.created_at || null};
};

const normalizeCreatePayload = async (data = {}) => {
  const payload = {
    ...data,
    tenant_id: await resolveIdentifierForPayload({
      value: data.tenant_id,
      model: 'tenant',
      field: 'tenant_id'}),
    coverage_plan_id: await resolveIdentifierForPayload({
      value: data.coverage_plan_id,
      model: 'coverage_plan',
      field: 'coverage_plan_id'})};

  if (payload.effective_from) payload.effective_from = new Date(payload.effective_from);
  if (payload.effective_to) payload.effective_to = new Date(payload.effective_to);

  return payload;
};

const normalizeUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(data, 'coverage_plan_id')) {
    payload.coverage_plan_id = await resolveIdentifierForPayload({
      value: data.coverage_plan_id,
      model: 'coverage_plan',
      field: 'coverage_plan_id'});
  }

  if (Object.prototype.hasOwnProperty.call(data, 'effective_from') && data.effective_from) {
    payload.effective_from = new Date(data.effective_from);
  }

  if (Object.prototype.hasOwnProperty.call(data, 'effective_to') && data.effective_to) {
    payload.effective_to = new Date(data.effective_to);
  }

  return payload;
};

/**
 * List scheme offers with pagination and filtering
 */
const listSchemeOffers = async (filters, page, limit, sortBy, order) => {
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

    if (filters.coverage_plan_id !== undefined) {
      const coveragePlanId = await resolveIdentifierForFilter({
        value: filters.coverage_plan_id,
        model: 'coverage_plan',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {}});
      if (coveragePlanId === null) return buildEmptyListResult(page, limit);
      if (coveragePlanId !== undefined) whereClause.coverage_plan_id = coveragePlanId;
    }

    if (filters.catalog_type) whereClause.catalog_type = filters.catalog_type;
    if (filters.catalog_item_id) whereClause.catalog_item_id = filters.catalog_item_id;
    if (filters.billing_entity) whereClause.billing_entity = filters.billing_entity;
    if (filters.is_excluded !== undefined) {
      whereClause.is_excluded = filters.is_excluded === true || filters.is_excluded === 'true';
    }
    if (filters.requires_pre_auth !== undefined) {
      whereClause.requires_pre_auth =
        filters.requires_pre_auth === true || filters.requires_pre_auth === 'true';
    }
    if (filters.is_active !== undefined) {
      whereClause.is_active = filters.is_active === true || filters.is_active === 'true';
    }

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { notes: { contains: search } },
        { catalog_item_id: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } }];
    }

    const [schemeOffers, total] = await Promise.all([
      schemeOfferRepository.findMany(whereClause, skip, limit, orderBy, SCHEME_OFFER_INCLUDE),
      schemeOfferRepository.count(whereClause)]);

    return {
      schemeOffers: schemeOffers.map(mapSchemeOfferForDisplay),
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
 * Get scheme offer by ID
 */
const getSchemeOfferById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'scheme_offer',
      identifier: id});

    const schemeOffer = await schemeOfferRepository.findById(resolvedId, SCHEME_OFFER_INCLUDE);

    if (!schemeOffer) {
      throw new HttpError('errors.scheme_offer.not_found', 404);
    }

    return mapSchemeOfferForDisplay(schemeOffer);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new scheme offer
 */
const createSchemeOffer = async (data, userId, ipAddress) => {
  try {
    const payload = await normalizeCreatePayload(data);
    const schemeOffer = await schemeOfferRepository.create(payload);
    const createdRecord = await schemeOfferRepository.findById(
      schemeOffer.id,
      SCHEME_OFFER_INCLUDE
    );

    createAuditLog({
      tenant_id: schemeOffer.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'scheme_offer',
      entity_id: schemeOffer.id,
      diff: { after: schemeOffer },
      ip_address: ipAddress}).catch(() => {});

    return mapSchemeOfferForDisplay(createdRecord || schemeOffer);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update scheme offer
 */
const updateSchemeOffer = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'scheme_offer',
      identifier: id});

    const before = await schemeOfferRepository.findById(resolvedId, SCHEME_OFFER_INCLUDE);

    if (!before) {
      throw new HttpError('errors.scheme_offer.not_found', 404);
    }

    const payload = await normalizeUpdatePayload(data);
    const schemeOffer = await schemeOfferRepository.update(before.id, payload);
    const updatedRecord = await schemeOfferRepository.findById(
      schemeOffer.id,
      SCHEME_OFFER_INCLUDE
    );

    createAuditLog({
      tenant_id: schemeOffer.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'scheme_offer',
      entity_id: schemeOffer.id,
      diff: { before, after: schemeOffer },
      ip_address: ipAddress}).catch(() => {});

    return mapSchemeOfferForDisplay(updatedRecord || schemeOffer);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete scheme offer (soft delete)
 */
const deleteSchemeOffer = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'scheme_offer',
      identifier: id});

    const before = await schemeOfferRepository.findById(resolvedId, SCHEME_OFFER_INCLUDE);

    if (!before) {
      throw new HttpError('errors.scheme_offer.not_found', 404);
    }

    await schemeOfferRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'scheme_offer',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress}).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listSchemeOffers,
  getSchemeOfferById,
  createSchemeOffer,
  updateSchemeOffer,
  deleteSchemeOffer};
