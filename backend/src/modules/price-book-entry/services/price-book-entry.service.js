/**
 * Price Book Entry service
 *
 * @module modules/price-book-entry/services
 * @description Business logic layer for price book entry operations.
 */

const prisma = require('@prisma/client');
const priceBookEntryRepository = require('@repositories/price-book-entry/price-book-entry.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');
const { resolveUnitPrices } = require('@lib/billing/price-resolver');
const {
  applyCoverageSplitToLineItems,
  summarizeCoverageShares} = require('@lib/billing/coverage-split');
const {
  assertPriceBookBillingEntityWrite,
} = require('@lib/billing/pricing-permissions');

const PRICE_BOOK_ENTRY_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  coverage_plan: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      provider_name: true,
      coverage_percentage: true,
      insurance_company_id: true}},
  insurance_company: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      code: true}}};

const buildEmptyListResult = (page, limit) => ({
  priceBookEntries: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1}});

const mapPriceBookEntryForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

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
    timeline_at: record?.timeline_at || record?.effective_from || record?.created_at || null};
};

const normalizeCreatePayload = async (data = {}) => {
  const payload = {
    ...data,
    tenant_id: await resolveIdentifierForPayload({
      value: data.tenant_id,
      model: 'tenant',
      field: 'tenant_id'}),
    facility_id: await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true}),
    coverage_plan_id: await resolveIdentifierForPayload({
      value: data.coverage_plan_id,
      model: 'coverage_plan',
      field: 'coverage_plan_id',
      nullable: true}),
    insurance_company_id: await resolveIdentifierForPayload({
      value: data.insurance_company_id,
      model: 'insurance_company',
      field: 'insurance_company_id',
      nullable: true})};

  if (payload.effective_from) payload.effective_from = new Date(payload.effective_from);
  if (payload.effective_to) payload.effective_to = new Date(payload.effective_to);

  return payload;
};

const normalizeUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true});
  }

  if (Object.prototype.hasOwnProperty.call(data, 'coverage_plan_id')) {
    payload.coverage_plan_id = await resolveIdentifierForPayload({
      value: data.coverage_plan_id,
      model: 'coverage_plan',
      field: 'coverage_plan_id',
      nullable: true});
  }

  if (Object.prototype.hasOwnProperty.call(data, 'insurance_company_id')) {
    payload.insurance_company_id = await resolveIdentifierForPayload({
      value: data.insurance_company_id,
      model: 'insurance_company',
      field: 'insurance_company_id',
      nullable: true});
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
 * List price book entries with pagination and filtering
 */
const listPriceBookEntries = async (filters, page, limit, sortBy, order) => {
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

    if (filters.facility_id !== undefined) {
      const facilityId = await resolveIdentifierForFilter({
        value: filters.facility_id,
        model: 'facility',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {}});
      if (facilityId === null) return buildEmptyListResult(page, limit);
      if (facilityId !== undefined) whereClause.facility_id = facilityId;
    }

    if (filters.coverage_plan_id !== undefined) {
      const coveragePlanId = await resolveIdentifierForFilter({
        value: filters.coverage_plan_id,
        model: 'coverage_plan',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {}});
      if (coveragePlanId === null) return buildEmptyListResult(page, limit);
      if (coveragePlanId !== undefined) whereClause.coverage_plan_id = coveragePlanId;
    }

    if (filters.insurance_company_id !== undefined) {
      const insuranceCompanyId = await resolveIdentifierForFilter({
        value: filters.insurance_company_id,
        model: 'insurance_company',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {}});
      if (insuranceCompanyId === null) return buildEmptyListResult(page, limit);
      if (insuranceCompanyId !== undefined) {
        whereClause.insurance_company_id = insuranceCompanyId;
      }
    }

    if (filters.catalog_type) whereClause.catalog_type = filters.catalog_type;
    if (filters.catalog_item_id) whereClause.catalog_item_id = filters.catalog_item_id;
    if (filters.payment_mode) whereClause.payment_mode = filters.payment_mode;
    if (filters.billing_entity) whereClause.billing_entity = filters.billing_entity;
    if (filters.is_active !== undefined) {
      whereClause.is_active = filters.is_active === true || filters.is_active === 'true';
    }

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { notes: { contains: search } },
        { insurer_key: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } }];
    }

    const [priceBookEntries, total] = await Promise.all([
      priceBookEntryRepository.findMany(whereClause, skip, limit, orderBy, PRICE_BOOK_ENTRY_INCLUDE),
      priceBookEntryRepository.count(whereClause)]);

    return {
      priceBookEntries: priceBookEntries.map(mapPriceBookEntryForDisplay),
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
 * Get price book entry by ID
 */
const getPriceBookEntryById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'price_book_entry',
      identifier: id});

    const priceBookEntry = await priceBookEntryRepository.findById(
      resolvedId,
      PRICE_BOOK_ENTRY_INCLUDE
    );

    if (!priceBookEntry) {
      throw new HttpError('errors.price_book_entry.not_found', 404);
    }

    return mapPriceBookEntryForDisplay(priceBookEntry);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new price book entry
 */
const createPriceBookEntry = async (data, userId, ipAddress, user = {}) => {
  try {
    const payload = await normalizeCreatePayload(data);
    assertPriceBookBillingEntityWrite(
      user,
      payload.billing_entity || data?.billing_entity || 'FACILITY'
    );
    const priceBookEntry = await priceBookEntryRepository.create(payload);
    const createdRecord = await priceBookEntryRepository.findById(
      priceBookEntry.id,
      PRICE_BOOK_ENTRY_INCLUDE
    );

    createAuditLog({
      tenant_id: priceBookEntry.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'price_book_entry',
      entity_id: priceBookEntry.id,
      diff: { after: priceBookEntry },
      ip_address: ipAddress}).catch(() => {});

    return mapPriceBookEntryForDisplay(createdRecord || priceBookEntry);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update price book entry
 */
const updatePriceBookEntry = async (id, data, userId, ipAddress, user = {}) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'price_book_entry',
      identifier: id});

    const before = await priceBookEntryRepository.findById(resolvedId, PRICE_BOOK_ENTRY_INCLUDE);

    if (!before) {
      throw new HttpError('errors.price_book_entry.not_found', 404);
    }

    const payload = await normalizeUpdatePayload(data);
    assertPriceBookBillingEntityWrite(
      user,
      payload.billing_entity || before.billing_entity || 'FACILITY'
    );
    const priceBookEntry = await priceBookEntryRepository.update(before.id, payload);
    const updatedRecord = await priceBookEntryRepository.findById(
      priceBookEntry.id,
      PRICE_BOOK_ENTRY_INCLUDE
    );

    createAuditLog({
      tenant_id: priceBookEntry.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'price_book_entry',
      entity_id: priceBookEntry.id,
      diff: { before, after: priceBookEntry },
      ip_address: ipAddress}).catch(() => {});

    return mapPriceBookEntryForDisplay(updatedRecord || priceBookEntry);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete price book entry (soft delete)
 */
const deletePriceBookEntry = async (id, userId, ipAddress, user = {}) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'price_book_entry',
      identifier: id});

    const before = await priceBookEntryRepository.findById(resolvedId, PRICE_BOOK_ENTRY_INCLUDE);

    if (!before) {
      throw new HttpError('errors.price_book_entry.not_found', 404);
    }

    assertPriceBookBillingEntityWrite(
      user,
      before.billing_entity || 'FACILITY'
    );

    await priceBookEntryRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'price_book_entry',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress}).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Resolve unit prices for catalog line items (with optional coverage split)
 */
const resolvePriceBookEntries = async (data) => {
  try {
    const tenantId = await resolveIdentifierForPayload({
      value: data?.tenant_id,
      field: 'tenant_id',
      model: 'tenant'});

    const facilityId = await resolveIdentifierForPayload({
      value: data?.facility_id,
      field: 'facility_id',
      model: 'facility',
      nullable: true});

    const coveragePlanId = await resolveIdentifierForPayload({
      value: data?.coverage_plan_id,
      field: 'coverage_plan_id',
      model: 'coverage_plan',
      nullable: true});

    const insuranceCompanyId = await resolveIdentifierForPayload({
      value: data?.insurance_company_id,
      field: 'insurance_company_id',
      model: 'insurance_company',
      nullable: true});

    const paymentMode = data?.payment_mode || 'SELF_PAY';
    const billingEntity = data?.billing_entity || 'FACILITY';
    const inputItems = Array.isArray(data?.items) ? data.items : [];

    const resolved = await resolveUnitPrices({
      tenantId,
      facilityId: facilityId || null,
      paymentMode,
      coveragePlanId: coveragePlanId || null,
      insuranceCompanyId: insuranceCompanyId || null,
      insurerKey: data?.insurer_key || null,
      billingEntity,
      currency: data?.currency || null,
      items: inputItems});

    let lineItems = inputItems.map((item, index) => {
      const price = resolved[index] || {};
      const quantity = Math.max(1, Number(item.quantity) || 1);
      const unitPrice = price.unitPrice ?? null;
      const lineTotal =
        unitPrice != null ? (Number(unitPrice) * quantity).toFixed(2) : null;

      return {
        id: item.id || null,
        catalog_type: item.catalog_type,
        catalog_item_id: item.catalog_item_id,
        quantity,
        unit_price: unitPrice,
        line_total: lineTotal,
        currency: price.currency || data?.currency || null,
        payment_mode: price.paymentMode || paymentMode,
        billing_entity: price.billingEntity || billingEntity,
        coverage_plan_id: price.coveragePlanId || coveragePlanId || null,
        insurance_company_id:
          price.insuranceCompanyId || insuranceCompanyId || null,
        insurer_key: price.insurerKey || data?.insurer_key || null,
        price_book_entry_id: price.priceBookEntryId || null,
        scheme_offer_id: price.schemeOfferId || null,
        source: price.source || 'UNRESOLVED',
        price_source: price.priceSource || item.price_source || billingEntity,
        coverage_percentage: price.coveragePercentage ?? null,
        copay_type: price.copayType || null,
        copay_value: price.copayValue ?? null,
        is_excluded: Boolean(price.isExcluded),
        requires_pre_auth: Boolean(price.requiresPreAuth)};
    });

    let coveragePlan = null;
    if (coveragePlanId) {
      coveragePlan = await prisma.coverage_plan.findFirst({
        where: { id: coveragePlanId, deleted_at: null },
        select: {
          id: true,
          coverage_percentage: true,
          name: true,
          provider_name: true,
          default_copay_type: true,
          default_copay_value: true,
          insurance_company_id: true}});
    }

    const shouldApplySplit =
      Boolean(coveragePlan) || String(paymentMode).toUpperCase() === 'INSURANCE';

    if (shouldApplySplit) {
      lineItems = applyCoverageSplitToLineItems(lineItems, {
        insured: String(paymentMode).toUpperCase() === 'INSURANCE',
        coveragePercentage: coveragePlan?.coverage_percentage ?? 0,
        coveragePlanId: coveragePlanId || null,
        insuranceCompanyId:
          insuranceCompanyId || coveragePlan?.insurance_company_id || null,
        paymentMode,
        copayType: coveragePlan?.default_copay_type || 'NONE',
        copayValue: coveragePlan?.default_copay_value ?? null});
    }

    const summary = summarizeCoverageShares(lineItems);

    return {
      items: lineItems,
      summary};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPriceBookEntries,
  getPriceBookEntryById,
  createPriceBookEntry,
  updatePriceBookEntry,
  deletePriceBookEntry,
  resolvePriceBookEntries};
