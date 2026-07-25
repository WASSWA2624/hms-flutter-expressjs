const labTestRepository = require('@repositories/lab-test/lab-test.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  LAB_TEST_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow} = require('@services/lab-workspace/lab.shared');
const {
  buildLabReferenceRangeSummary,
  normalizeLabResultOptions,
  normalizeLabReferenceRanges,
  normalizeLabUnitOptions,
  toOptionalText} = require('@services/lab-workspace/lab.configuration');
const { mapLabTestRecord } = require('@services/lab-workspace/lab.serializer');
const { STANDARD_LAB_TESTS } = require('@services/lab-order/lab-order.service');
const {
  checkLabTestDuplicates,
  mergeDuplicateChecks
} = require('@lib/lab/lab-test-similarity');
const { publishCrudRealtimeEvent } = require('@lib/websocket/crud-realtime');
const { DIAGNOSTIC_EVENTS } = require('@lib/websocket/events');

const publishLabCatalogRealtimeUpdate = async ({
  resource,
  actorUserId = null,
  action = 'UPDATED'
} = {}) => {
  if (!resource?.tenant_id || !resource?.id) {
    return;
  }
  publishCrudRealtimeEvent({
    event: DIAGNOSTIC_EVENTS.LAB_CATALOG_UPDATED,
    resource,
    resource_type: 'lab_test',
    actor_user_id: actorUserId,
    payload: {
      action: String(action || 'UPDATED').trim().toUpperCase(),
      deleted_at: resource.deleted_at || null,
      name: resource.name || null,
      code: resource.code || null,
      category: resource.category || null,
      human_friendly_id: resource.human_friendly_id || null
    }
  })?.catch?.(() => {});
};

const hasOwn = (value, key) => Object.prototype.hasOwnProperty.call(value || {}, key);
const standardLabTestId = (key) => `STD_LAB_TEST:${key}`;
const normalizeText = (value) => String(value || '').trim();
const includesIgnoreCase = (value, query) => normalizeText(value).toLowerCase().includes(query);

const standardLabTestMatchesFilters = (key, definition, filters = {}) => {
  if (filters.code && !includesIgnoreCase(definition.code, normalizeText(filters.code).toLowerCase())) return false;
  if (filters.name && !includesIgnoreCase(definition.name, normalizeText(filters.name).toLowerCase())) return false;
  if (filters.category && !includesIgnoreCase(definition.category, normalizeText(filters.category).toLowerCase())) return false;
  if (filters.specimen_type && !includesIgnoreCase(definition.specimen_type, normalizeText(filters.specimen_type).toLowerCase())) return false;
  if (filters.result_kind && definition.result_kind !== filters.result_kind) return false;

  const search = normalizeText(filters.search).toLowerCase();
  if (!search) return true;
  return [
    standardLabTestId(key),
    definition.name,
    definition.code,
    definition.category,
    definition.specimen_type,
    definition.result_kind,
    definition.unit,
    definition.description].some((value) => includesIgnoreCase(value, search));
};

const standardLabTestRecord = ([key, definition]) => ({
  id: standardLabTestId(key),
  display_id: standardLabTestId(key),
  human_friendly_id: standardLabTestId(key),
  name: definition.name,
  code: definition.code,
  category: definition.category,
  specimen_type: definition.specimen_type,
  result_kind: definition.result_kind,
  unit: definition.unit,
  description: definition.description,
  status: 'STANDARD',
  source: 'STANDARD_LAB_CATALOG'});

const mergeStandardLabTests = ({ mappedRecords, dbRecords, filters, limit, sortBy, order }) => {
  if (String(filters.include_standard_catalog || '').toLowerCase() !== 'true') {
    return mappedRecords;
  }

  const existingCodes = new Set(
    dbRecords.map((record) => normalizeText(record?.code).toUpperCase()).filter(Boolean)
  );
  const standardRecords = Object.entries(STANDARD_LAB_TESTS)
    .filter(([key, definition]) => (
      !existingCodes.has(normalizeText(definition.code).toUpperCase())
      && standardLabTestMatchesFilters(key, definition, filters)
    ))
    .map(standardLabTestRecord);

  const direction = String(order || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  const sortableField = sortBy || 'name';
  const compare = (left, right) => (
    normalizeText(left?.[sortableField] || left?.name)
      .localeCompare(normalizeText(right?.[sortableField] || right?.name)) * direction
  );

  // Always keep tenant/db rows. Fill remaining page slots with standards so a
  // late-alphabet custom test (e.g. "testing") is never sliced away.
  const sortedMapped = [...mappedRecords].sort(compare);
  const remaining = Math.max(0, (Number(limit) || 0) - sortedMapped.length);
  const sortedStandards = [...standardRecords].sort(compare).slice(0, remaining);
  return [...sortedMapped, ...sortedStandards].sort(compare);
};

const withoutChildIdentifier = (entry = {}) => {
  const { id, ...data } = entry;
  return data;
};

const buildNestedChildWritePayload = (entries = [], options = {}) => {
  const preserveExisting = options.preserveExisting === true;

  if (!preserveExisting) {
    return {
      create: entries.map(withoutChildIdentifier)};
  }

  const existingRows = entries.filter((entry) => toOptionalText(entry.id));
  const existingIds = existingRows.map((entry) => entry.id);
  const createRows = entries.filter((entry) => !toOptionalText(entry.id));
  const payload = {
    deleteMany: existingIds.length > 0 ? { id: { notIn: existingIds } } : {}};

  if (createRows.length > 0) {
    payload.create = createRows.map(withoutChildIdentifier);
  }

  if (existingRows.length > 0) {
    payload.update = existingRows.map((entry) => ({
      where: { id: entry.id },
      data: withoutChildIdentifier(entry)}));
  }

  return payload;
};

const buildLabTestWritePayload = (data = {}, options = {}) => {
  const payload = { ...data };
  delete payload.confirm_similar;
  const preserveExistingChildren = options.includeDeleteMany === true;
  const hasReferenceRanges = hasOwn(payload, 'reference_ranges');
  const normalizedRanges = hasReferenceRanges
    ? normalizeLabReferenceRanges(payload.reference_ranges)
    : [];
  const hasUnitOptions = hasOwn(payload, 'unit_options');
  const normalizedUnitOptions = hasUnitOptions
    ? normalizeLabUnitOptions(payload.unit_options)
    : [];
  const hasResultOptions = hasOwn(payload, 'result_options');
  const normalizedResultOptions = hasResultOptions
    ? normalizeLabResultOptions(payload.result_options)
    : [];

  if (hasReferenceRanges) {
    payload.reference_ranges = buildNestedChildWritePayload(normalizedRanges, {
      preserveExisting: preserveExistingChildren});
  } else {
    delete payload.reference_ranges;
  }

  if (hasOwn(data, 'reference_range') || hasReferenceRanges) {
    payload.reference_range = buildLabReferenceRangeSummary(
      payload.reference_range,
      normalizedRanges
    );
  }

  const fallbackUnit = toOptionalText(payload.unit);
  const defaultUnitOption = normalizedUnitOptions.find((entry) => entry.is_default)
    || normalizedUnitOptions[0]
    || null;

  if (hasUnitOptions) {
    payload.unit_options = buildNestedChildWritePayload(normalizedUnitOptions, {
      preserveExisting: preserveExistingChildren});
    payload.unit = defaultUnitOption?.unit || fallbackUnit || null;
  } else if (options.createDefaultUnitOption && fallbackUnit) {
    payload.unit_options = {
      create: [
        {
          label: null,
          unit: fallbackUnit,
          ucum_code: null,
          is_default: true,
          sort_order: 0}]};
    payload.unit = fallbackUnit;
  } else {
    delete payload.unit_options;
  }

  if (hasResultOptions) {
    payload.result_options = buildNestedChildWritePayload(normalizedResultOptions, {
      preserveExisting: preserveExistingChildren});
  } else {
    delete payload.result_options;
  }

  return payload;
};


const listLabTests = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};
    if (filters.tenant_id) {
      whereClause.tenant_id = await resolveModelIdOrThrow({
        identifier: filters.tenant_id,
        model: 'tenant',
        where: { deleted_at: null },
        errorKey: 'errors.tenant.not_found'});
    }

    if (filters.code) whereClause.code = { contains: filters.code };
    if (filters.name) whereClause.name = { contains: filters.name };
    if (filters.category) whereClause.category = { contains: filters.category };
    if (filters.specimen_type) {
      whereClause.specimen_type = { contains: filters.specimen_type };
    }
    if (filters.result_kind) whereClause.result_kind = filters.result_kind;
    if (String(filters.include_pending_review || '').toLowerCase() !== 'true') {
      // NULL descriptions must remain visible: SQL treats NOT (NULL LIKE ...) as
      // unknown and would otherwise drop custom tests with no description.
      whereClause.NOT = {
        AND: [
          { description: { not: null } },
          { description: { startsWith: 'PENDING LAB CATALOG REVIEW' } },
        ],
      };
    }

    const searchTerm = normalizeSearchTerm(filters.search);
    if (searchTerm) {
      whereClause.OR = [
        { human_friendly_id: { contains: searchTerm.upper } },
        { name: { contains: searchTerm.raw } },
        { code: { contains: searchTerm.raw } },
        { category: { contains: searchTerm.raw } },
        { specimen_type: { contains: searchTerm.raw } },
        { description: { contains: searchTerm.raw } },
        { tenant: { human_friendly_id: { contains: searchTerm.upper } } }];
    }

    const [labTests, total] = await Promise.all([
      labTestRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        LAB_TEST_WITH_RELATIONS_INCLUDE
      ),
      labTestRepository.count(whereClause)]);
    const mappedLabTests = labTests.map((record) => mapLabTestRecord(record)).filter(Boolean);
    const mergedLabTests = mergeStandardLabTests({
      mappedRecords: mappedLabTests,
      dbRecords: labTests,
      filters,
      limit,
      sortBy,
      order});

    return {
      labTests: mergedLabTests,
      pagination: buildPagination(
        page,
        limit,
        String(filters.include_standard_catalog || '').toLowerCase() === 'true'
          ? Math.max(total, mergedLabTests.length)
          : total
      )};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabTestById = async (id, userId, ipAddress) => {
  try {
    const labTest = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_test',
      where: { deleted_at: null },
      include: LAB_TEST_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_test.not_found'});

    return mapLabTestRecord(labTest);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const assertLabTestUniqueness = async ({
  name,
  code,
  category,
  tenantId,
  excludeTestId = null,
  confirmSimilar = false
}) => {
  const existingDbTests = await labTestRepository.findMany(
    { tenant_id: tenantId },
    0,
    7500,
    { name: 'asc' }
  );
  const standardCandidates = Object.entries(STANDARD_LAB_TESTS).map(
    ([key, definition]) => ({
      id: standardLabTestId(key),
      display_id: standardLabTestId(key),
      human_friendly_id: standardLabTestId(key),
      name: definition.name,
      code: definition.code,
      category: definition.category
    })
  );
  const duplicateCheck = mergeDuplicateChecks(
    checkLabTestDuplicates({
      name,
      code,
      category,
      existing: existingDbTests,
      excludeTestId,
      includeTokenSimilarity: true
    }),
    checkLabTestDuplicates({
      name,
      code,
      category,
      existing: standardCandidates,
      excludeTestId,
      includeTokenSimilarity: false
    })
  );

  if (duplicateCheck.exactNameConflict) {
    throw new HttpError('errors.lab_test.duplicate_name', 409, [
      { field: 'name' }
    ]);
  }
  if (duplicateCheck.exactCodeConflict) {
    throw new HttpError('errors.lab_test.duplicate_code', 409, [
      { field: 'code' }
    ]);
  }
  if (
    duplicateCheck.nonExactSimilarMatches.length > 0
    && !confirmSimilar
  ) {
    throw new HttpError('errors.lab_test.similar_exists', 409, [
      {
        field: 'name',
        matches: duplicateCheck.nonExactSimilarMatches.slice(0, 5)
      }
    ]);
  }
};

const createLabTest = async (data, userId, ipAddress) => {
  try {
    const confirmSimilar = data?.confirm_similar === true;
    const payload = buildLabTestWritePayload(data, {
      createDefaultUnitOption: true,
      includeDeleteMany: false});
    payload.tenant_id = await resolveModelIdOrThrow({
      identifier: payload.tenant_id,
      model: 'tenant',
      where: { deleted_at: null },
      errorKey: 'errors.tenant.not_found'});

    await assertLabTestUniqueness({
      name: payload.name ?? data.name,
      code: payload.code ?? data.code,
      category: payload.category ?? data.category,
      tenantId: payload.tenant_id,
      confirmSimilar
    });

    const labTest = await labTestRepository.create(payload);
    const created = await labTestRepository.findById(labTest.id, LAB_TEST_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'lab_test',
      entity_id: labTest.id,
      diff: { after: created || labTest },
      ip_address: ipAddress}).catch(() => {});

    const mapped = mapLabTestRecord(created || labTest);
    publishLabCatalogRealtimeUpdate({
      resource: created || labTest,
      actorUserId: userId,
      action: 'CREATED'
    });
    return mapped;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateLabTest = async (id, data, userId, ipAddress) => {
  try {
    const confirmSimilar = data?.confirm_similar === true;
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_test',
      where: { deleted_at: null },
      include: LAB_TEST_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_test.not_found'});

    const payload = buildLabTestWritePayload(data, { includeDeleteMany: true });
    delete payload.confirm_similar;
    if (Object.prototype.hasOwnProperty.call(payload, 'tenant_id') && payload.tenant_id) {
      payload.tenant_id = await resolveModelIdOrThrow({
        identifier: payload.tenant_id,
        model: 'tenant',
        where: { deleted_at: null },
        errorKey: 'errors.tenant.not_found'});
    }

    const nextName = Object.prototype.hasOwnProperty.call(payload, 'name')
      ? payload.name
      : before.name;
    const nextCode = Object.prototype.hasOwnProperty.call(payload, 'code')
      ? payload.code
      : before.code;
    const nextCategory = Object.prototype.hasOwnProperty.call(payload, 'category')
      ? payload.category
      : before.category;
    const tenantId = payload.tenant_id || before.tenant_id;

    await assertLabTestUniqueness({
      name: nextName,
      code: nextCode,
      category: nextCategory,
      tenantId,
      excludeTestId: before.id,
      confirmSimilar
    });

    const updated = await labTestRepository.update(before.id, payload);
    const labTest = await labTestRepository.findById(updated.id, LAB_TEST_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'lab_test',
      entity_id: updated.id,
      diff: { before, after: labTest },
      ip_address: ipAddress}).catch(() => {});

    const mapped = mapLabTestRecord(labTest || updated);
    publishLabCatalogRealtimeUpdate({
      resource: labTest || updated,
      actorUserId: userId,
      action: 'UPDATED'
    });
    return mapped;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabTest = async (id, data = {}, userId, ipAddress) => {
  try {
    const deletionReason = normalizeText(data?.reason);
    if (!deletionReason) {
      throw new HttpError('errors.validation.required', 400, [
        { field: 'reason' }]);
    }

    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_test',
      where: { deleted_at: null },
      include: LAB_TEST_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_test.not_found'});

    const labTest = await labTestRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'lab_test',
      entity_id: labTest.id,
      diff: { before, deletion_reason: deletionReason },
      ip_address: ipAddress}).catch(() => {});

    publishLabCatalogRealtimeUpdate({
      resource: { ...before, deleted_at: labTest?.deleted_at || new Date() },
      actorUserId: userId,
      action: 'SOFT_DELETED'
    });

    return mapLabTestRecord(before);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listLabTests,
  getLabTestById,
  createLabTest,
  updateLabTest,
  deleteLabTest
};
