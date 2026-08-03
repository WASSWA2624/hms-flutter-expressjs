/**
 * Facility pharmacy catalog service
 */

const drugRepository = require('@repositories/drug/drug.repository');
const facilityPharmacyCatalogRepository = require('@repositories/facility-pharmacy-catalog/facility-pharmacy-catalog.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveOperationalFacilityId } = require('@lib/facility-context');
const {
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/pharmacy-workspace/pharmacy.shared');
const { mapMergedDrugRecord } = require('@services/pharmacy-workspace/facility-pharmacy-catalog.merge');
const { resolveDefaultStorageShelfId } = require('@services/pharmacy-workspace/pharmacy-storage.service');

const normalizeText = (value) => String(value || '').trim();
const isTrue = (value) => String(value || '').toLowerCase() === 'true';
const toOptionalText = (value) => {
  const normalized = normalizeText(value);
  return normalized || null;
};

const resolveFacilityId = async (context = {}, payload = {}) => {
  const facilityId = await resolveOperationalFacilityId({
    facilityId: payload.facility_id || context.facility_id || null,
    userId: context.user_id || null,
    tenantId: context.tenant_id || payload.tenant_id || null,
  });
  if (!facilityId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'facility_id' }]);
  }
  return resolveModelIdOrThrow({
    model: 'facility',
    identifier: facilityId,
    tenantId: context.tenant_id,
  });
};

const resolveDrugIdOrThrow = async ({ identifier, tenantId, errorKey = 'errors.drug.not_found' }) =>
  resolveModelIdOrThrow({
    model: 'drug',
    identifier,
    tenantId,
    errorKey,
  });

const buildDrugSearchWhere = (tenantId, searchTerm) => {
  const where = { tenant_id: tenantId, deleted_at: null };
  if (!searchTerm?.raw) return where;
  return {
    ...where,
    OR: [
      { name: { contains: searchTerm.raw } },
      { brand_name: { contains: searchTerm.raw } },
      { generic_name: { contains: searchTerm.raw } },
      { code: { contains: searchTerm.raw } },
      { form: { contains: searchTerm.raw } },
      { strength: { contains: searchTerm.raw } },
    ],
  };
};

const listFacilityPharmacyDrugs = async (filters, page, limit, sortBy, order, context = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, filters);
  const skip = (page - 1) * limit;
  const orderBy = sortBy ? { [sortBy]: order || 'asc' } : { name: 'asc' };
  const searchTerm = normalizeSearchTerm(filters.search);
  const offeredOnly = isTrue(filters.offered_only);
  const includeInactive = isTrue(filters.include_inactive);

  if (offeredOnly) {
    const offeringWhere = {
      tenant_id: tenantId,
      facility_id: facilityId,
      ...(includeInactive ? {} : { is_active: true }),
      ...(searchTerm?.raw
        ? {
            drug: {
              deleted_at: null,
              OR: [
                { name: { contains: searchTerm.raw } },
                { brand_name: { contains: searchTerm.raw } },
                { generic_name: { contains: searchTerm.raw } },
                { code: { contains: searchTerm.raw } },
                { form: { contains: searchTerm.raw } },
                { strength: { contains: searchTerm.raw } },
              ],
            },
          }
        : {}),
    };
    const offerings = await facilityPharmacyCatalogRepository.findDrugOfferings(
      offeringWhere,
      skip,
      limit,
      { sort_order: 'asc' }
    );
    const missingDrugIds = offerings
      .filter((offering) => !offering.drug && offering.drug_id)
      .map((offering) => offering.drug_id);
    const missingDrugsMap = new Map();
    if (missingDrugIds.length > 0) {
      const missingDrugs = await drugRepository.findMany(
        { id: { in: missingDrugIds }, deleted_at: null },
        0,
        missingDrugIds.length
      );
      missingDrugs.forEach((drug) => missingDrugsMap.set(drug.id, drug));
    }
    const items = offerings
      .map((offering) => {
        const masterDrug = offering.drug || missingDrugsMap.get(offering.drug_id) || null;
        return mapMergedDrugRecord(masterDrug, offering);
      })
      .filter(Boolean);
    const total = await facilityPharmacyCatalogRepository.countDrugOfferings(offeringWhere);
    return { items, pagination: buildPagination(page, limit, total) };
  }

  const masterWhere = buildDrugSearchWhere(tenantId, searchTerm);
  const [masterDrugs, total] = await Promise.all([
    drugRepository.findMany(masterWhere, skip, limit, orderBy),
    drugRepository.count(masterWhere),
  ]);
  const offeringRows = await facilityPharmacyCatalogRepository.findDrugOfferings(
    {
      tenant_id: tenantId,
      facility_id: facilityId,
      drug_id: { in: masterDrugs.map((row) => row.id) },
    },
    0,
    masterDrugs.length
  );
  const offeringByDrugId = new Map(offeringRows.map((row) => [row.drug_id, row]));
  const items = masterDrugs
    .map((masterDrug) => mapMergedDrugRecord(masterDrug, offeringByDrugId.get(masterDrug.id) || null))
    .filter(Boolean);

  return { items, pagination: buildPagination(page, limit, total) };
};

const getFacilityPharmacyDrug = async (drugIdentifier, context = {}, filters = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) throw new HttpError('errors.auth.unauthorized', 401);
  const facilityId = await resolveFacilityId(context, filters);
  const drugId = await resolveDrugIdOrThrow({ identifier: drugIdentifier, tenantId });
  const masterDrug = await resolveModelRecordOrThrow({
    model: 'drug',
    identifier: drugId,
    tenantId,
  });
  const offering = await facilityPharmacyCatalogRepository.findDrugOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    drug_id: drugId,
  });
  return mapMergedDrugRecord(masterDrug, offering);
};

const upsertFacilityPharmacyOffering = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id;
  const userId = context.user_id;
  if (!tenantId || !userId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, payload);
  const drugId = await resolveDrugIdOrThrow({
    identifier: payload.drug_id,
    tenantId,
  });
  const masterDrug = await resolveModelRecordOrThrow({
    model: 'drug',
    identifier: drugId,
    tenantId,
  });

  const existing = await facilityPharmacyCatalogRepository.findDrugOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    drug_id: drugId,
  });

  let defaultStorageShelfId = null;
  const hasShelfField = Object.prototype.hasOwnProperty.call(
    payload,
    'default_storage_shelf_id'
  );
  if (hasShelfField && payload.default_storage_shelf_id) {
    defaultStorageShelfId = await resolveDefaultStorageShelfId(
      payload.default_storage_shelf_id,
      { tenant_id: tenantId, user_id: userId, facility_id: facilityId },
      facilityId
    );
  }

  const writePayload = {
    tenant_id: tenantId,
    facility_id: facilityId,
    drug_id: drugId,
    is_active: payload.is_active !== false,
    sort_order: Number(payload.sort_order || 0),
    unit_price:
      payload.unit_price != null
        ? payload.unit_price
        : existing?.unit_price != null
          ? existing.unit_price
          : 0,
    currency:
      toOptionalText(payload.currency) ||
      existing?.currency ||
      masterDrug.currency ||
      null,
    ...(hasShelfField ? { default_storage_shelf_id: defaultStorageShelfId } : {}),
  };

  const offering = existing
    ? await facilityPharmacyCatalogRepository.updateDrugOffering(existing.id, writePayload)
    : await facilityPharmacyCatalogRepository.createDrugOffering(writePayload);

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: existing ? 'UPDATE' : 'CREATE',
    entity: 'facility_pharmacy_offering',
    entity_id: offering.id,
    diff: { after: offering },
    ip_address: context.ip_address,
  }).catch(() => {});

  return mapMergedDrugRecord(masterDrug, offering);
};

const disableFacilityPharmacyOffering = async (drugIdentifier, payload = {}, context = {}) => {
  const tenantId = context.tenant_id;
  const userId = context.user_id;
  if (!tenantId || !userId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, payload);
  const drugId = await resolveDrugIdOrThrow({ identifier: drugIdentifier, tenantId });
  const existing = await facilityPharmacyCatalogRepository.findDrugOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    drug_id: drugId,
  });
  if (!existing) {
    throw new HttpError('errors.facility_pharmacy_offering.not_found', 404);
  }

  await facilityPharmacyCatalogRepository.updateDrugOffering(existing.id, {
    is_active: false,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'UPDATE',
    entity: 'facility_pharmacy_offering',
    entity_id: existing.id,
    diff: {
      metadata: {
        disabled: true,
        reason: payload.reason || null,
      },
    },
    ip_address: context.ip_address,
  }).catch(() => {});
};

module.exports = {
  listFacilityPharmacyDrugs,
  getFacilityPharmacyDrug,
  upsertFacilityPharmacyOffering,
  disableFacilityPharmacyOffering,
};
