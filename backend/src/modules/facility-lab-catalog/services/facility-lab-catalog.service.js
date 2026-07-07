/**
 * Facility lab catalog service
 */

const prisma = require('@prisma/client');
const labTestRepository = require('@repositories/lab-test/lab-test.repository');
const labPanelRepository = require('@repositories/lab-panel/lab-panel.repository');
const facilityLabCatalogRepository = require('@repositories/facility-lab-catalog/facility-lab-catalog.repository');
const clinicalTermRepository = require('@repositories/clinical-term/clinical-term.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { STANDARD_LAB_TESTS, STANDARD_LAB_PANELS } = require('@services/lab-order/lab-order.service');
const {
  LAB_TEST_WITH_RELATIONS_INCLUDE,
  LAB_PANEL_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const {
  buildLabReferenceRangeSummary,
  normalizeLabReferenceRanges,
  normalizeLabResultOptions,
  normalizeLabUnitOptions,
  toOptionalText,
} = require('@services/lab-workspace/lab.configuration');
const { resolveOperationalFacilityId } = require('@lib/facility-context');
const {
  mapMergedLabPanelRecord,
  mapMergedLabTestRecord,
  mapClinicalCatalogLabPanelRow,
  mapClinicalCatalogLabTestRow,
  mergeLabTestWithOffering,
} = require('@services/lab-workspace/facility-lab-catalog.merge');
const { emitToUsers, DIAGNOSTIC_EVENTS } = require('@lib/websocket');
const {
  resolveFacilityLabCatalogRecipients,
} = require('@services/lab-workspace/lab.realtime');

const publishLabCatalogRealtimeUpdate = async ({
  tenantId,
  facilityId,
  termType,
  action,
  resourceId = null,
  isActive = null,
  actorUserId = null,
} = {}) => {
  try {
    const recipientUserIds = await resolveFacilityLabCatalogRecipients({
      tenantId,
      facilityId,
      actorUserId,
    });
    if (!recipientUserIds.length) return;

    emitToUsers(recipientUserIds, DIAGNOSTIC_EVENTS.LAB_CATALOG_UPDATED, {
      tenant_id: tenantId || null,
      facility_id: facilityId || null,
      term_type: String(termType || 'LAB_TEST').toUpperCase(),
      resource_type: 'facility_lab_catalog',
      resource_id: resourceId,
      is_active: isActive,
      action: String(action || 'UPDATED').trim().toUpperCase(),
      occurred_at: new Date().toISOString(),
      target_path: '/lab',
    });
  } catch (_error) {
    // Realtime updates must never block catalog persistence.
  }
};

const hasOwn = (value, key) => Object.prototype.hasOwnProperty.call(value || {}, key);
const normalizeText = (value) => String(value || '').trim();
const isTrue = (value) => String(value || '').toLowerCase() === 'true';

const standardCatalogCodeFromIdentifier = (identifier, prefix) => {
  const normalized = normalizeText(identifier).toUpperCase();
  if (!normalized.startsWith(`${prefix}:`)) {
    return null;
  }
  return normalized.slice(prefix.length + 1);
};

const resolveOrCreateStandardLabTest = async ({
  identifier,
  tenantId,
  userId,
  ipAddress,
}) => {
  const catalogCode = standardCatalogCodeFromIdentifier(identifier, 'STD_LAB_TEST');
  if (!catalogCode) {
    return null;
  }

  const definition = STANDARD_LAB_TESTS[catalogCode];
  if (!definition) {
    return null;
  }

  const existing = await prisma.lab_test.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      code: definition.code,
    },
    select: { id: true },
  });
  if (existing) {
    return existing;
  }

  const labTest = await prisma.lab_test.create({
    data: {
      tenant_id: tenantId,
      name: definition.name,
      code: definition.code,
      category: definition.category,
      specimen_type: definition.specimen_type,
      result_kind: definition.result_kind,
      unit: definition.unit,
      description: definition.description,
      ...(definition.unit
        ? {
            unit_options: {
              create: [
                {
                  label: null,
                  unit: definition.unit,
                  ucum_code: null,
                  is_default: true,
                  sort_order: 0,
                },
              ],
            },
          }
        : {}),
    },
    select: { id: true },
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId || null,
    action: 'CREATE',
    entity: 'lab_test',
    entity_id: labTest.id,
    diff: {
      after: { ...definition, id: labTest.id, source: 'STANDARD_LAB_CATALOG' },
    },
    ip_address: ipAddress,
  }).catch(() => {});

  return labTest;
};

const standardPanelNameFromCode = (catalogCode) =>
  normalizeText(catalogCode)
    .replace(/^PANEL_/, '')
    .replace(/^LOINC_/, 'LOINC ')
    .replace(/_/g, ' ');

const resolveOrCreateStandardLabPanel = async ({
  identifier,
  tenantId,
  userId,
  ipAddress,
}) => {
  const catalogCode = standardCatalogCodeFromIdentifier(identifier, 'STD_LAB_PANEL');
  if (!catalogCode) {
    return null;
  }

  const testCodes = STANDARD_LAB_PANELS[catalogCode];
  if (!Array.isArray(testCodes) || !testCodes.length) {
    return null;
  }

  const existing = await prisma.lab_panel.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      code: catalogCode,
    },
    select: { id: true },
  });
  if (existing) {
    return existing;
  }

  const panelItems = [];
  for (let index = 0; index < testCodes.length; index += 1) {
    const testCode = testCodes[index];
    const labTest = await resolveOrCreateStandardLabTest({
      identifier: `STD_LAB_TEST:${testCode}`,
      tenantId,
      userId,
      ipAddress,
    });
    if (!labTest?.id) {
      continue;
    }
    const definition = STANDARD_LAB_TESTS[testCode] || {};
    panelItems.push({
      lab_test_id: labTest.id,
      is_required: true,
      sort_order: index,
      instructions: null,
      unit: definition.unit || null,
    });
  }

  if (!panelItems.length) {
    return null;
  }

  const labPanel = await prisma.lab_panel.create({
    data: {
      tenant_id: tenantId,
      name: standardPanelNameFromCode(catalogCode),
      code: catalogCode,
      category: 'STANDARD',
      description: 'Standard lab panel',
      panel_items: {
        create: panelItems,
      },
    },
    select: { id: true },
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId || null,
    action: 'CREATE',
    entity: 'lab_panel',
    entity_id: labPanel.id,
    diff: {
      after: {
        id: labPanel.id,
        code: catalogCode,
        source: 'STANDARD_LAB_CATALOG',
      },
    },
    ip_address: ipAddress,
  }).catch(() => {});

  return labPanel;
};

const resolveLabPanelIdOrThrow = async ({
  identifier,
  tenantId,
  context = {},
  errorKey = 'errors.lab_panel.not_found',
}) => {
  const standardLabPanel = await resolveOrCreateStandardLabPanel({
    identifier,
    tenantId,
    userId: context.user_id,
    ipAddress: context.ip_address,
  });
  if (standardLabPanel?.id) {
    return standardLabPanel.id;
  }

  return resolveModelIdOrThrow({
    model: 'lab_panel',
    identifier,
    tenantId,
    errorKey,
  });
};

const resolveLabTestIdOrThrow = async ({
  identifier,
  tenantId,
  context = {},
  errorKey = 'errors.lab_test.not_found',
}) => {
  const standardLabTest = await resolveOrCreateStandardLabTest({
    identifier,
    tenantId,
    userId: context.user_id,
    ipAddress: context.ip_address,
  });
  if (standardLabTest?.id) {
    return standardLabTest.id;
  }

  return resolveModelIdOrThrow({
    model: 'lab_test',
    identifier,
    tenantId,
    errorKey,
  });
};

const withoutChildIdentifier = (entry = {}) => {
  const { id, ...data } = entry;
  return data;
};

const buildNestedChildWritePayload = (entries = [], options = {}) => {
  const preserveExisting = options.preserveExisting === true;
  if (!preserveExisting) {
    return { create: entries.map(withoutChildIdentifier) };
  }

  const existingRows = entries.filter((entry) => toOptionalText(entry.id));
  const existingIds = existingRows.map((entry) => entry.id);
  const createRows = entries.filter((entry) => !toOptionalText(entry.id));
  const payload = {
    deleteMany: existingIds.length > 0 ? { id: { notIn: existingIds } } : {},
  };
  if (createRows.length > 0) {
    payload.create = createRows.map(withoutChildIdentifier);
  }
  if (existingRows.length > 0) {
    payload.update = existingRows.map((entry) => ({
      where: { id: entry.id },
      data: withoutChildIdentifier(entry),
    }));
  }
  return payload;
};

const buildOfferingWritePayload = (payload = {}, options = {}) => {
  const data = { ...payload };
  const preserveExistingChildren = options.includeDeleteMany === true;
  const hasReferenceRanges = hasOwn(data, 'reference_ranges');
  const normalizedRanges = hasReferenceRanges
    ? normalizeLabReferenceRanges(data.reference_ranges)
    : [];
  const hasUnitOptions = hasOwn(data, 'unit_options');
  const normalizedUnitOptions = hasUnitOptions
    ? normalizeLabUnitOptions(data.unit_options)
    : [];
  const hasResultOptions = hasOwn(data, 'result_options');
  const normalizedResultOptions = hasResultOptions
    ? normalizeLabResultOptions(data.result_options)
    : [];

  if (hasReferenceRanges) {
    data.reference_ranges = buildNestedChildWritePayload(normalizedRanges, {
      preserveExisting: preserveExistingChildren,
    });
  } else {
    delete data.reference_ranges;
  }

  if (hasOwn(data, 'reference_range') || hasReferenceRanges) {
    data.reference_range = buildLabReferenceRangeSummary(data.reference_range, normalizedRanges);
  }

  if (hasUnitOptions) {
    data.unit_options = buildNestedChildWritePayload(normalizedUnitOptions, {
      preserveExisting: preserveExistingChildren,
    });
    const defaultUnitOption = normalizedUnitOptions.find((entry) => entry.is_default)
      || normalizedUnitOptions[0]
      || null;
    if (defaultUnitOption?.unit) {
      data.unit = defaultUnitOption.unit;
    }
  } else {
    delete data.unit_options;
  }

  if (hasResultOptions) {
    data.result_options = buildNestedChildWritePayload(normalizedResultOptions, {
      preserveExisting: preserveExistingChildren,
    });
  } else {
    delete data.result_options;
  }

  return data;
};

const copyMasterDefaults = (masterTest = {}) => ({
  reference_ranges: (masterTest.reference_ranges || []).map((entry) => ({
    label: entry.label,
    unit: entry.unit,
    gender: entry.gender,
    age_min_value: entry.age_min_value,
    age_min_unit: entry.age_min_unit,
    age_max_value: entry.age_max_value,
    age_max_unit: entry.age_max_unit,
    normal_min_value: entry.normal_min_value,
    normal_max_value: entry.normal_max_value,
    critical_min_value: entry.critical_min_value,
    critical_max_value: entry.critical_max_value,
    reference_text: entry.reference_text,
    notes: entry.notes,
    sort_order: entry.sort_order,
  })),
  unit_options: (masterTest.unit_options || []).map((entry) => ({
    label: entry.label,
    unit: entry.unit,
    ucum_code: entry.ucum_code,
    is_default: entry.is_default,
    sort_order: entry.sort_order,
  })),
  result_options: (masterTest.result_options || []).map((entry) => ({
    value: entry.value,
    label: entry.label,
    aliases_json: entry.aliases_json,
    status: entry.status,
    result_flag: entry.result_flag,
    is_positive: entry.is_positive,
    sort_order: entry.sort_order,
  })),
  reference_range: masterTest.reference_range,
});

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

const syncLegacyOffering = async ({ tenantId, facilityId, labTestId, isActive }) => {
  const existing = await clinicalTermRepository.findFacilityOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    term_type: 'LAB_TEST',
    item_id: labTestId,
    deleted_at: null,
  });

  const data = {
    tenant_id: tenantId,
    facility_id: facilityId,
    term_type: 'LAB_TEST',
    item_id: labTestId,
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
  return {
    ...where,
    OR: [
      { name: { contains: searchTerm.raw } },
      { code: { contains: searchTerm.raw } },
      { category: { contains: searchTerm.raw } },
      { specimen_type: { contains: searchTerm.raw } },
      { description: { contains: searchTerm.raw } },
    ],
  };
};

const buildPanelSearchWhere = (tenantId, searchTerm) => {
  const where = { tenant_id: tenantId };
  if (!searchTerm?.raw) return where;
  return {
    ...where,
    OR: [
      { name: { contains: searchTerm.raw } },
      { code: { contains: searchTerm.raw } },
      { category: { contains: searchTerm.raw } },
      { description: { contains: searchTerm.raw } },
    ],
  };
};

const listFacilityLabTests = async (filters, page, limit, sortBy, order, context = {}) => {
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
    };
    const offerings = await facilityLabCatalogRepository.findTestOfferings(
      offeringWhere,
      skip,
      limit,
      { sort_order: 'asc' }
    );
    const items = offerings
      .map((offering) => mapMergedLabTestRecord(offering.lab_test, offering))
      .filter(Boolean);
    const total = await facilityLabCatalogRepository.countTestOfferings(offeringWhere);
    return { items, pagination: buildPagination(page, limit, total) };
  }

  const masterWhere = buildTestSearchWhere(tenantId, searchTerm);
  const [masterTests, total] = await Promise.all([
    labTestRepository.findMany(masterWhere, skip, limit, orderBy, LAB_TEST_WITH_RELATIONS_INCLUDE),
    labTestRepository.count(masterWhere),
  ]);
  const offeringRows = await facilityLabCatalogRepository.findTestOfferings(
    {
      tenant_id: tenantId,
      facility_id: facilityId,
      lab_test_id: { in: masterTests.map((row) => row.id) },
    },
    0,
    masterTests.length
  );
  const offeringByTestId = new Map(offeringRows.map((row) => [row.lab_test_id, row]));
  const items = masterTests.map((masterTest) =>
    mapMergedLabTestRecord(masterTest, offeringByTestId.get(masterTest.id) || null)
  );

  return { items, pagination: buildPagination(page, limit, total) };
};

const listFacilityLabPanels = async (filters, page, limit, sortBy, order, context = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, filters);
  const skip = (page - 1) * limit;
  const orderBy = sortBy ? { [sortBy]: order || 'asc' } : { name: 'asc' };
  const searchTerm = normalizeSearchTerm(filters.search);
  const offeredOnly = isTrue(filters.offered_only);

  if (offeredOnly) {
    const offeringWhere = { tenant_id: tenantId, facility_id: facilityId, is_active: true };
    const offerings = await facilityLabCatalogRepository.findPanelOfferings(
      offeringWhere,
      skip,
      limit,
      { sort_order: 'asc' }
    );
    const items = offerings
      .map((offering) => mapMergedLabPanelRecord(offering.lab_panel, offering))
      .filter(Boolean);
    const total = await facilityLabCatalogRepository.countPanelOfferings(offeringWhere);
    return { items, pagination: buildPagination(page, limit, total) };
  }

  const masterWhere = buildPanelSearchWhere(tenantId, searchTerm);
  const [masterPanels, total] = await Promise.all([
    labPanelRepository.findMany(masterWhere, skip, limit, orderBy, LAB_PANEL_WITH_RELATIONS_INCLUDE),
    labPanelRepository.count(masterWhere),
  ]);
  const offeringRows = await facilityLabCatalogRepository.findPanelOfferings(
    {
      tenant_id: tenantId,
      facility_id: facilityId,
      lab_panel_id: { in: masterPanels.map((row) => row.id) },
    },
    0,
    masterPanels.length
  );
  const offeringByPanelId = new Map(offeringRows.map((row) => [row.lab_panel_id, row]));
  const items = masterPanels.map((masterPanel) =>
    mapMergedLabPanelRecord(masterPanel, offeringByPanelId.get(masterPanel.id) || null)
  );

  return { items, pagination: buildPagination(page, limit, total) };
};

const getFacilityLabTest = async (labTestIdentifier, context = {}, filters = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) throw new HttpError('errors.auth.unauthorized', 401);
  const facilityId = await resolveFacilityId(context, filters);
  const labTestId = await resolveLabTestIdOrThrow({
    identifier: labTestIdentifier,
    tenantId,
    context,
  });
  const masterTest = await resolveModelRecordOrThrow({
    model: 'lab_test',
    identifier: labTestId,
    tenantId,
    include: LAB_TEST_WITH_RELATIONS_INCLUDE,
  });
  const offering = await facilityLabCatalogRepository.findTestOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_test_id: labTestId,
  });
  return mapMergedLabTestRecord(masterTest, offering);
};

const getFacilityLabPanel = async (labPanelIdentifier, context = {}, filters = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) throw new HttpError('errors.auth.unauthorized', 401);
  const facilityId = await resolveFacilityId(context, filters);
  const labPanelId = await resolveLabPanelIdOrThrow({
    identifier: labPanelIdentifier,
    tenantId,
    context,
  });
  const masterPanel = await resolveModelRecordOrThrow({
    model: 'lab_panel',
    identifier: labPanelId,
    tenantId,
    include: LAB_PANEL_WITH_RELATIONS_INCLUDE,
  });
  const offering = await facilityLabCatalogRepository.findPanelOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_panel_id: labPanelId,
  });
  return mapMergedLabPanelRecord(masterPanel, offering);
};

const upsertFacilityLabTestOffering = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id;
  const userId = context.user_id;
  if (!tenantId || !userId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, payload);
  const labTestId = await resolveLabTestIdOrThrow({
    identifier: payload.lab_test_id,
    tenantId,
    context,
  });
  const masterTest = await resolveModelRecordOrThrow({
    model: 'lab_test',
    identifier: labTestId,
    tenantId,
    include: LAB_TEST_WITH_RELATIONS_INCLUDE,
  });

  const existing = await facilityLabCatalogRepository.findTestOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_test_id: labTestId,
  });

  const shouldSeedDefaults = !existing
    && payload.is_active !== false
    && !hasOwn(payload, 'reference_ranges')
    && !hasOwn(payload, 'unit_options')
    && !hasOwn(payload, 'result_options');

  const basePayload = {
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_test_id: labTestId,
    is_active: payload.is_active !== false,
    sort_order: Number(payload.sort_order || 0),
    unit_price: payload.unit_price,
    currency: toOptionalText(payload.currency) || masterTest.currency || null,
    specimen_type: toOptionalText(payload.specimen_type),
    result_kind: payload.result_kind || null,
    unit: toOptionalText(payload.unit),
    description: toOptionalText(payload.description),
    reference_range: toOptionalText(payload.reference_range),
    ...(shouldSeedDefaults ? copyMasterDefaults(masterTest) : {}),
    ...(hasOwn(payload, 'reference_ranges') ? { reference_ranges: payload.reference_ranges } : {}),
    ...(hasOwn(payload, 'unit_options') ? { unit_options: payload.unit_options } : {}),
    ...(hasOwn(payload, 'result_options') ? { result_options: payload.result_options } : {}),
  };

  const writePayload = buildOfferingWritePayload(basePayload, {
    includeDeleteMany: Boolean(existing),
  });

  const offering = existing
    ? await facilityLabCatalogRepository.updateTestOffering(existing.id, writePayload)
    : await facilityLabCatalogRepository.createTestOffering(writePayload);

  await syncLegacyOffering({
    tenantId,
    facilityId,
    labTestId,
    isActive: offering.is_active,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: existing ? 'UPDATE' : 'CREATE',
    entity: 'facility_lab_test_offering',
    entity_id: offering.id,
    diff: { after: offering },
    ip_address: context.ip_address,
  }).catch(() => {});

  publishLabCatalogRealtimeUpdate({
    tenantId,
    facilityId,
    termType: 'LAB_TEST',
    action: existing ? 'UPDATED' : 'ENABLED',
    resourceId: labTestId,
    isActive: offering.is_active,
    actorUserId: userId,
  });

  return mapMergedLabTestRecord(masterTest, offering);
};

const disableFacilityLabTestOffering = async (labTestIdentifier, payload = {}, context = {}) => {
  const tenantId = context.tenant_id;
  const userId = context.user_id;
  if (!tenantId || !userId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, payload);
  const labTestId = await resolveLabTestIdOrThrow({
    identifier: labTestIdentifier,
    tenantId,
    context,
  });
  const offering = await facilityLabCatalogRepository.findTestOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_test_id: labTestId,
  });
  if (!offering) {
    throw new HttpError('errors.facility_lab_test_offering.not_found', 404);
  }

  const updated = await facilityLabCatalogRepository.updateTestOffering(offering.id, {
    is_active: false,
    deleted_at: new Date(),
  });

  await syncLegacyOffering({ tenantId, facilityId, labTestId, isActive: false });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'DELETE',
    entity: 'facility_lab_test_offering',
    entity_id: offering.id,
    diff: { before: offering, reason: normalizeText(payload.reason) },
    ip_address: context.ip_address,
  }).catch(() => {});

  publishLabCatalogRealtimeUpdate({
    tenantId,
    facilityId,
    termType: 'LAB_TEST',
    action: 'DISABLED',
    resourceId: labTestId,
    isActive: false,
    actorUserId: userId,
  });

  return updated;
};

const upsertFacilityLabPanelOffering = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id;
  const userId = context.user_id;
  if (!tenantId || !userId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, payload);
  const labPanelId = await resolveLabPanelIdOrThrow({
    identifier: payload.lab_panel_id,
    tenantId,
    context,
  });
  const masterPanel = await resolveModelRecordOrThrow({
    model: 'lab_panel',
    identifier: labPanelId,
    tenantId,
    include: LAB_PANEL_WITH_RELATIONS_INCLUDE,
  });

  const existing = await facilityLabCatalogRepository.findPanelOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_panel_id: labPanelId,
  });

  const writePayload = {
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_panel_id: labPanelId,
    is_active: payload.is_active !== false,
    sort_order: Number(payload.sort_order || 0),
    unit_price: payload.unit_price,
    currency: toOptionalText(payload.currency) || masterPanel.currency || null,
  };

  const offering = existing
    ? await facilityLabCatalogRepository.updatePanelOffering(existing.id, writePayload)
    : await facilityLabCatalogRepository.createPanelOffering(writePayload);

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: existing ? 'UPDATE' : 'CREATE',
    entity: 'facility_lab_panel_offering',
    entity_id: offering.id,
    diff: { after: offering },
    ip_address: context.ip_address,
  }).catch(() => {});

  publishLabCatalogRealtimeUpdate({
    tenantId,
    facilityId,
    termType: 'LAB_PANEL',
    action: existing ? 'UPDATED' : 'ENABLED',
    resourceId: labPanelId,
    isActive: offering.is_active,
    actorUserId: userId,
  });

  return mapMergedLabPanelRecord(masterPanel, offering);
};

const disableFacilityLabPanelOffering = async (labPanelIdentifier, payload = {}, context = {}) => {
  const tenantId = context.tenant_id;
  const userId = context.user_id;
  if (!tenantId || !userId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, payload);
  const labPanelId = await resolveLabPanelIdOrThrow({
    identifier: labPanelIdentifier,
    tenantId,
    context,
  });
  const offering = await facilityLabCatalogRepository.findPanelOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_panel_id: labPanelId,
  });
  if (!offering) {
    throw new HttpError('errors.facility_lab_panel_offering.not_found', 404);
  }

  const updated = await facilityLabCatalogRepository.updatePanelOffering(offering.id, {
    is_active: false,
    deleted_at: new Date(),
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'DELETE',
    entity: 'facility_lab_panel_offering',
    entity_id: offering.id,
    diff: { before: offering, reason: normalizeText(payload.reason) },
    ip_address: context.ip_address,
  }).catch(() => {});

  publishLabCatalogRealtimeUpdate({
    tenantId,
    facilityId,
    termType: 'LAB_PANEL',
    action: 'DISABLED',
    resourceId: labPanelId,
    isActive: false,
    actorUserId: userId,
  });

  return updated;
};

const searchFacilityLabCatalog = async (filters = {}, context = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) throw new HttpError('errors.auth.unauthorized', 401);

  const facilityId = await resolveFacilityId(context, filters);
  const limit = Number(filters.limit || 25);
  const searchTerm = normalizeSearchTerm(filters.q);
  const offeredOnly = filters.offered_only !== 'false';
  const termType = String(filters.term_type || 'LAB_TEST').toUpperCase();

  if (termType === 'LAB_PANEL') {
    const offeringWhere = {
      tenant_id: tenantId,
      facility_id: facilityId,
      is_active: true,
      ...(searchTerm?.raw
        ? {
            lab_panel: {
              deleted_at: null,
              OR: [
                { name: { contains: searchTerm.raw } },
                { code: { contains: searchTerm.raw } },
                { category: { contains: searchTerm.raw } },
              ],
            },
          }
        : {}),
    };
    const offerings = await facilityLabCatalogRepository.findPanelOfferings(
      offeringWhere,
      0,
      limit,
      { sort_order: 'asc' }
    );
    return offerings
      .map((offering) => mapClinicalCatalogLabPanelRow(offering.lab_panel, offering))
      .filter(Boolean);
  }

  const offeringWhere = {
    tenant_id: tenantId,
    facility_id: facilityId,
    is_active: offeredOnly ? true : undefined,
    ...(searchTerm?.raw
      ? {
          lab_test: {
            deleted_at: null,
            OR: [
              { name: { contains: searchTerm.raw } },
              { code: { contains: searchTerm.raw } },
              { category: { contains: searchTerm.raw } },
            ],
          },
        }
      : {}),
  };
  const offerings = await facilityLabCatalogRepository.findTestOfferings(
    offeringWhere,
    0,
    limit,
    { sort_order: 'asc' }
  );
  return offerings
    .map((offering) => mapClinicalCatalogLabTestRow(offering.lab_test, offering))
    .filter(Boolean);
};

const resolveFacilityLabTestForInterpretation = async ({
  tenantId,
  facilityId,
  labTestId,
  masterTest = null,
}) => {
  if (!tenantId || !facilityId || !labTestId) {
    return masterTest;
  }

  const offering = await facilityLabCatalogRepository.findTestOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    lab_test_id: labTestId,
    is_active: true,
  });
  if (!offering) {
    return masterTest;
  }
  return mergeLabTestWithOffering(masterTest, offering) || masterTest;
};

module.exports = {
  listFacilityLabTests,
  listFacilityLabPanels,
  getFacilityLabTest,
  getFacilityLabPanel,
  upsertFacilityLabTestOffering,
  disableFacilityLabTestOffering,
  upsertFacilityLabPanelOffering,
  disableFacilityLabPanelOffering,
  searchFacilityLabCatalog,
  resolveFacilityLabTestForInterpretation,
};
