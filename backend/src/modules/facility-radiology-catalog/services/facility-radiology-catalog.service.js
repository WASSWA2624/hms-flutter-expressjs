/**
 * Facility radiology catalog service
 */

const radiologyProcedureRepository = require('@repositories/radiology-procedure/radiology-procedure.repository');
const facilityRadiologyCatalogRepository = require('@repositories/facility-radiology-catalog/facility-radiology-catalog.repository');
const clinicalTermRepository = require('@repositories/clinical-term/clinical-term.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveOrCreateStandardRadiologyTest } = require('@services/radiology-procedure/radiology-procedure.service');
const {
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/radiology-workspace/radiology.shared');
const { resolveOperationalFacilityId } = require('@lib/facility-context');
const {
  mapMergedRadiologyTestRecord,
  mapClinicalCatalogRadiologyTestRow,
} = require('@services/radiology-workspace/facility-radiology-catalog.merge');
const {
  buildRadiologyProcedureSearchFilter,
  buildRadiologyProcedureSearchOr,
} = require('@lib/radiology/radiology-procedure-search');

const normalizeText = (value) => String(value || '').trim();
const isTrue = (value) => String(value || '').toLowerCase() === 'true';
const toOptionalText = (value) => {
  const normalized = normalizeText(value);
  return normalized || null;
};

const standardCodeFromIdentifier = (identifier) => {
  const normalized = normalizeText(identifier).toUpperCase();
  if (!normalized.startsWith('STD_RAD_TEST_')) {
    return null;
  }
  return normalized.slice('STD_RAD_TEST_'.length);
};

const resolveRadiologyTestIdOrThrow = async ({
  identifier,
  tenantId,
  context = {},
  errorKey = 'errors.radiology_test.not_found',
}) => {
  const standardCode = standardCodeFromIdentifier(identifier);
  if (standardCode) {
    const standardRadiologyTest = await resolveOrCreateStandardRadiologyTest({
      code: standardCode,
      tenantId,
      userId: context.user_id,
      ipAddress: context.ip_address,
    });
    if (standardRadiologyTest?.id) {
      return standardRadiologyTest.id;
    }
  }

  return resolveModelIdOrThrow({
    model: 'radiology_procedure',
    identifier,
    tenantId,
    errorKey,
  });
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

const syncLegacyOffering = async ({ tenantId, facilityId, radiologyTestId, isActive }) => {
  const existing = await clinicalTermRepository.findFacilityOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    term_type: 'RADIOLOGY_TEST',
    item_id: radiologyTestId,
    deleted_at: null,
  });

  const data = {
    tenant_id: tenantId,
    facility_id: facilityId,
    term_type: 'RADIOLOGY_TEST',
    item_id: radiologyTestId,
    is_active: isActive !== false,
  };

  if (existing) {
    await clinicalTermRepository.updateFacilityOffering(existing.id, data);
    return;
  }
  if (isActive !== false) {
    await clinicalTermRepository.createFacilityOffering(data);
  }
};

const buildTestSearchWhere = (tenantId, searchTerm) => {
  const where = { tenant_id: tenantId };
  if (!searchTerm?.raw) return where;
  const or = buildRadiologyProcedureSearchOr(searchTerm.raw);
  if (or.length === 0) return where;
  return {
    ...where,
    OR: or,
  };
};

const listFacilityRadiologyTests = async (filters, page, limit, sortBy, order, context = {}) => {
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
            radiology_procedure: buildRadiologyProcedureSearchFilter(
              searchTerm.raw
            ),
          }
        : {}),
    };
    const offerings = await facilityRadiologyCatalogRepository.findTestOfferings(
      offeringWhere,
      skip,
      limit,
      { sort_order: 'asc' }
    );
    const items = (
      await Promise.all(
        offerings.map(async (offering) => {
          const masterTest =
            offering.radiology_procedure ||
            (offering.radiology_procedure_id
              ? await radiologyProcedureRepository.findById(offering.radiology_procedure_id)
              : null);
          return mapMergedRadiologyTestRecord(masterTest, offering);
        })
      )
    ).filter(Boolean);
    const total = await facilityRadiologyCatalogRepository.countTestOfferings(offeringWhere);
    return { items, pagination: buildPagination(page, limit, total) };
  }

  const masterWhere = buildTestSearchWhere(tenantId, searchTerm);
  const [masterTests, total] = await Promise.all([
    radiologyProcedureRepository.findMany(masterWhere, skip, limit, orderBy),
    radiologyProcedureRepository.count(masterWhere),
  ]);
  const offeringRows = await facilityRadiologyCatalogRepository.findTestOfferings(
    {
      tenant_id: tenantId,
      facility_id: facilityId,
      radiology_procedure_id: { in: masterTests.map((row) => row.id) },
    },
    0,
    masterTests.length
  );
  const offeringByTestId = new Map(offeringRows.map((row) => [row.radiology_procedure_id, row]));
  const items = masterTests.map((masterTest) =>
    mapMergedRadiologyTestRecord(masterTest, offeringByTestId.get(masterTest.id) || null)
  );

  return { items, pagination: buildPagination(page, limit, total) };
};

const getFacilityRadiologyTest = async (radiologyTestIdentifier, context = {}, filters = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) throw new HttpError('errors.auth.unauthorized', 401);
  const facilityId = await resolveFacilityId(context, filters);
  const radiologyTestId = await resolveRadiologyTestIdOrThrow({
    identifier: radiologyTestIdentifier,
    tenantId,
    context,
  });
  const masterTest = await resolveModelRecordOrThrow({
    model: 'radiology_procedure',
    identifier: radiologyTestId,
    tenantId,
  });
  const offering = await facilityRadiologyCatalogRepository.findTestOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    radiology_procedure_id: radiologyTestId,
  });
  return mapMergedRadiologyTestRecord(masterTest, offering);
};

const upsertFacilityRadiologyTestOffering = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id;
  const userId = context.user_id;
  if (!tenantId || !userId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, payload);
  const radiologyTestId = await resolveRadiologyTestIdOrThrow({
    identifier: payload.radiology_procedure_id ?? payload.radiology_test_id,
    tenantId,
    context,
  });
  const masterTest = await resolveModelRecordOrThrow({
    model: 'radiology_procedure',
    identifier: radiologyTestId,
    tenantId,
  });

  const existing = await facilityRadiologyCatalogRepository.findTestOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    radiology_procedure_id: radiologyTestId,
  });

  const writePayload = {
    tenant_id: tenantId,
    facility_id: facilityId,
    radiology_procedure_id: radiologyTestId,
    is_active: payload.is_active !== false,
    sort_order: Number(payload.sort_order || 0),
    unit_price: payload.unit_price,
    currency: toOptionalText(payload.currency) || masterTest.currency || null,
  };

  const offering = existing
    ? await facilityRadiologyCatalogRepository.updateTestOffering(existing.id, writePayload)
    : await facilityRadiologyCatalogRepository.createTestOffering(writePayload);

  await syncLegacyOffering({
    tenantId,
    facilityId,
    radiologyTestId,
    isActive: offering.is_active,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: existing ? 'UPDATE' : 'CREATE',
    entity: 'facility_radiology_procedure_offering',
    entity_id: offering.id,
    diff: { after: offering },
    ip_address: context.ip_address,
  }).catch(() => {});

  return mapMergedRadiologyTestRecord(masterTest, offering);
};

const disableFacilityRadiologyTestOffering = async (
  radiologyTestIdentifier,
  payload = {},
  context = {}
) => {
  const tenantId = context.tenant_id;
  const userId = context.user_id;
  if (!tenantId || !userId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, payload);
  const radiologyTestId = await resolveRadiologyTestIdOrThrow({
    identifier: radiologyTestIdentifier,
    tenantId,
    context,
  });
  const offering = await facilityRadiologyCatalogRepository.findTestOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    radiology_procedure_id: radiologyTestId,
  });
  if (!offering) {
    throw new HttpError('errors.facility_radiology_test_offering.not_found', 404);
  }

  const updated = await facilityRadiologyCatalogRepository.updateTestOffering(offering.id, {
    is_active: false,
    deleted_at: new Date(),
  });

  await syncLegacyOffering({
    tenantId,
    facilityId,
    radiologyTestId,
    isActive: false,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'DELETE',
    entity: 'facility_radiology_procedure_offering',
    entity_id: offering.id,
    diff: { before: offering, reason: normalizeText(payload.reason) },
    ip_address: context.ip_address,
  }).catch(() => {});

  return updated;
};

const searchFacilityRadiologyCatalog = async (filters = {}, context = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, filters);
  const limit = Number(filters.limit || 25);
  const searchTerm = normalizeSearchTerm(filters.q);
  const offeredOnly = filters.offered_only !== 'false';

  const offeringWhere = {
    tenant_id: tenantId,
    facility_id: facilityId,
    is_active: offeredOnly ? true : undefined,
    ...(searchTerm?.raw
      ? {
          radiology_procedure: buildRadiologyProcedureSearchFilter(
            searchTerm.raw
          ),
        }
      : {}),
  };
  const offerings = await facilityRadiologyCatalogRepository.findTestOfferings(
    offeringWhere,
    0,
    limit,
    { sort_order: 'asc' }
  );
  return offerings
    .map((offering) => mapClinicalCatalogRadiologyTestRow(offering.radiology_procedure, offering))
    .filter(Boolean);
};

module.exports = {
  listFacilityRadiologyTests,
  getFacilityRadiologyTest,
  upsertFacilityRadiologyTestOffering,
  disableFacilityRadiologyTestOffering,
  searchFacilityRadiologyCatalog,
};
