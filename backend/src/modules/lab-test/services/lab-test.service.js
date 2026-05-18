const labTestRepository = require('@repositories/lab-test/lab-test.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  LAB_TEST_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const {
  buildLabReferenceRangeSummary,
  normalizeLabResultOptions,
  normalizeLabReferenceRanges,
  normalizeLabUnitOptions,
  toOptionalText,
} = require('@services/lab-workspace/lab.configuration');
const { mapLabTestRecord } = require('@services/lab-workspace/lab.serializer');
const { STANDARD_LAB_TESTS } = require('@services/lab-order/lab-order.service');

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
    definition.description,
  ].some((value) => includesIgnoreCase(value, search));
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
  source: 'STANDARD_LAB_CATALOG',
});

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
  return [...mappedRecords, ...standardRecords]
    .sort((left, right) => (
      normalizeText(left?.[sortableField] || left?.name)
        .localeCompare(normalizeText(right?.[sortableField] || right?.name)) * direction
    ))
    .slice(0, limit);
};

const buildLabTestWritePayload = (data = {}, options = {}) => {
  const payload = { ...data };
  const includeDeleteMany = options.includeDeleteMany === true;
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
    payload.reference_ranges = {
      ...(includeDeleteMany ? { deleteMany: {} } : {}),
      create: normalizedRanges,
    };
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
    payload.unit_options = {
      ...(includeDeleteMany ? { deleteMany: {} } : {}),
      create: normalizedUnitOptions,
    };
    payload.unit = defaultUnitOption?.unit || fallbackUnit || null;
  } else if (options.createDefaultUnitOption && fallbackUnit) {
    payload.unit_options = {
      create: [
        {
          label: null,
          unit: fallbackUnit,
          ucum_code: null,
          is_default: true,
          sort_order: 0,
        },
      ],
    };
    payload.unit = fallbackUnit;
  } else {
    delete payload.unit_options;
  }

  if (hasResultOptions) {
    payload.result_options = {
      ...(includeDeleteMany ? { deleteMany: {} } : {}),
      create: normalizedResultOptions,
    };
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
        errorKey: 'errors.tenant.not_found',
      });
    }

    if (filters.code) whereClause.code = { contains: filters.code };
    if (filters.name) whereClause.name = { contains: filters.name };
    if (filters.category) whereClause.category = { contains: filters.category };
    if (filters.specimen_type) {
      whereClause.specimen_type = { contains: filters.specimen_type };
    }
    if (filters.result_kind) whereClause.result_kind = filters.result_kind;
    if (String(filters.include_pending_review || '').toLowerCase() !== 'true') {
      whereClause.NOT = {
        description: { startsWith: 'PENDING LAB CATALOG REVIEW' },
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
        { tenant: { human_friendly_id: { contains: searchTerm.upper } } },
      ];
    }

    const [labTests, total] = await Promise.all([
      labTestRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        LAB_TEST_WITH_RELATIONS_INCLUDE
      ),
      labTestRepository.count(whereClause),
    ]);
    const mappedLabTests = labTests.map((record) => mapLabTestRecord(record)).filter(Boolean);
    const mergedLabTests = mergeStandardLabTests({
      mappedRecords: mappedLabTests,
      dbRecords: labTests,
      filters,
      limit,
      sortBy,
      order,
    });

    return {
      labTests: mergedLabTests,
      pagination: buildPagination(
        page,
        limit,
        String(filters.include_standard_catalog || '').toLowerCase() === 'true'
          ? Math.max(total, mergedLabTests.length)
          : total
      ),
    };
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
      errorKey: 'errors.lab_test.not_found',
    });

    return mapLabTestRecord(labTest);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createLabTest = async (data, userId, ipAddress) => {
  try {
    const payload = buildLabTestWritePayload(data, {
      createDefaultUnitOption: true,
      includeDeleteMany: false,
    });
    payload.tenant_id = await resolveModelIdOrThrow({
      identifier: payload.tenant_id,
      model: 'tenant',
      where: { deleted_at: null },
      errorKey: 'errors.tenant.not_found',
    });

    const labTest = await labTestRepository.create(payload);
    const created = await labTestRepository.findById(labTest.id, LAB_TEST_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'lab_test',
      entity_id: labTest.id,
      diff: { after: created || labTest },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabTestRecord(created || labTest);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateLabTest = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_test',
      where: { deleted_at: null },
      include: LAB_TEST_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_test.not_found',
    });

    const payload = buildLabTestWritePayload(data, { includeDeleteMany: true });
    if (Object.prototype.hasOwnProperty.call(payload, 'tenant_id') && payload.tenant_id) {
      payload.tenant_id = await resolveModelIdOrThrow({
        identifier: payload.tenant_id,
        model: 'tenant',
        where: { deleted_at: null },
        errorKey: 'errors.tenant.not_found',
      });
    }

    const updated = await labTestRepository.update(before.id, payload);
    const labTest = await labTestRepository.findById(updated.id, LAB_TEST_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'lab_test',
      entity_id: updated.id,
      diff: { before, after: labTest },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabTestRecord(labTest || updated);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabTest = async (id, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_test',
      where: { deleted_at: null },
      include: LAB_TEST_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_test.not_found',
    });

    const labTest = await labTestRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'lab_test',
      entity_id: labTest.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});

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
