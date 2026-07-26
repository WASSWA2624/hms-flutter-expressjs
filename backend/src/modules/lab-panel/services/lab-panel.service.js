const labPanelRepository = require('@repositories/lab-panel/lab-panel.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  LAB_PANEL_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow} = require('@services/lab-workspace/lab.shared');
const {
  normalizeLabPanelItems} = require('@services/lab-workspace/lab.configuration');
const { mapLabPanelRecord } = require('@services/lab-workspace/lab.serializer');
const { STANDARD_LAB_PANELS, STANDARD_LAB_TESTS } = require('@services/lab-order/lab-order.service');
const {
  checkLabPanelDuplicates,
  mergePanelDuplicateChecks
} = require('@lib/lab/lab-panel-similarity');
const { publishCrudRealtimeEvent } = require('@lib/websocket/crud-realtime');
const { DIAGNOSTIC_EVENTS } = require('@lib/websocket/events');

const publishLabPanelCatalogRealtimeUpdate = async ({
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
    resource_type: 'lab_panel',
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
const standardLabPanelId = (key) => `STD_LAB_PANEL:${key}`;
const standardLabTestId = (key) => `STD_LAB_TEST:${key}`;
const normalizeText = (value) => String(value || '').trim();
const includesIgnoreCase = (value, query) => normalizeText(value).toLowerCase().includes(query);
const standardPanelName = (key) =>
  normalizeText(key)
    .replace(/^PANEL_/, '')
    .replace(/^LOINC_/, 'LOINC ')
    .replace(/_/g, ' ');

const standardLabPanelMatchesFilters = (key, testCodes, filters = {}) => {
  const name = standardPanelName(key);
  if (filters.code && !includesIgnoreCase(key, normalizeText(filters.code).toLowerCase())) return false;
  if (filters.name && !includesIgnoreCase(name, normalizeText(filters.name).toLowerCase())) return false;
  if (filters.category && !includesIgnoreCase('STANDARD', normalizeText(filters.category).toLowerCase())) return false;

  const search = normalizeText(filters.search).toLowerCase();
  if (!search) return true;
  return [
    standardLabPanelId(key),
    name,
    key,
    'STANDARD',
    ...testCodes,
    ...testCodes.map((testCode) => STANDARD_LAB_TESTS[testCode]?.name)].some((value) => includesIgnoreCase(value, search));
};

const standardLabPanelRecord = ([key, testCodes]) => ({
  id: standardLabPanelId(key),
  display_id: standardLabPanelId(key),
  human_friendly_id: standardLabPanelId(key),
  name: standardPanelName(key),
  code: key,
  category: 'STANDARD',
  description: 'Standard lab panel',
  status: 'STANDARD',
  source: 'STANDARD_LAB_CATALOG',
  panel_items: testCodes.map((testCode, index) => {
    const definition = STANDARD_LAB_TESTS[testCode] || {};
    return {
      id: `${standardLabPanelId(key)}:${testCode}`,
      lab_test_id: standardLabTestId(testCode),
      test_display_name: definition.name || testCode,
      test_code: definition.code || testCode,
      unit: definition.unit || null,
      is_required: true,
      instructions: null,
      sort_order: index};
  }),
  test_count: testCodes.length});

const mergeStandardLabPanels = ({ mappedRecords, filters, limit, sortBy, order }) => {
  if (String(filters.include_standard_catalog || '').toLowerCase() !== 'true') {
    return mappedRecords;
  }

  const existingCodes = new Set(
    mappedRecords.map((record) => normalizeText(record?.code).toUpperCase()).filter(Boolean)
  );
  const standardRecords = Object.entries(STANDARD_LAB_PANELS)
    .filter(([key, testCodes]) => (
      !existingCodes.has(key.toUpperCase())
      && standardLabPanelMatchesFilters(key, testCodes, filters)
    ))
    .map(standardLabPanelRecord);

  const direction = String(order || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  const sortableField = sortBy || 'name';
  const compare = (left, right) => (
    normalizeText(left?.[sortableField] || left?.name)
      .localeCompare(normalizeText(right?.[sortableField] || right?.name)) * direction
  );

  const sortedMapped = [...mappedRecords].sort(compare);
  const remaining = Math.max(0, (Number(limit) || 0) - sortedMapped.length);
  const sortedStandards = [...standardRecords].sort(compare).slice(0, remaining);
  return [...sortedMapped, ...sortedStandards].sort(compare);
};

const resolvePanelItems = async (items, tenantId) => {
  const normalizedItems = normalizeLabPanelItems(items);
  return Promise.all(
    normalizedItems.map(async (entry) => ({
      ...entry,
      lab_test_id: await resolveModelIdOrThrow({
        identifier: entry.lab_test_id,
        model: 'lab_test',
        where: {
          deleted_at: null,
          tenant_id: tenantId},
        errorKey: 'errors.lab_test.not_found'})}))
  );
};

/**
 * Resolve member tests to internal ids + codes so composition overlap works
 * when the client only sends lab_test_id (friendly or uuid).
 */
const enrichPanelItemsForSimilarity = async (items = [], tenantId) => {
  const normalizedItems = normalizeLabPanelItems(items);
  return Promise.all(
    normalizedItems.map(async (entry) => {
      const labTest = await resolveModelRecordOrThrow({
        identifier: entry.lab_test_id,
        model: 'lab_test',
        where: {
          deleted_at: null,
          tenant_id: tenantId
        },
        errorKey: 'errors.lab_test.not_found'
      });
      return {
        lab_test_id: labTest.id,
        test_code: labTest.code || entry.test_code || null,
        lab_test: {
          id: labTest.id,
          human_friendly_id: labTest.human_friendly_id,
          code: labTest.code
        }
      };
    })
  );
};

const buildPanelWritePayload = async (data = {}, tenantId, options = {}) => {
  const payload = { ...data };
  const includeDeleteMany = options.includeDeleteMany === true;

  if (hasOwn(payload, 'panel_items')) {
    const resolvedItems = await resolvePanelItems(payload.panel_items, tenantId);
    payload.panel_items = {
      ...(includeDeleteMany ? { deleteMany: {} } : {}),
      create: resolvedItems};
  } else {
    delete payload.panel_items;
  }

  return payload;
};

const standardPanelCandidates = () => Object.entries(STANDARD_LAB_PANELS).map(
  ([key, testCodes]) => ({
    id: standardLabPanelId(key),
    display_id: standardLabPanelId(key),
    human_friendly_id: standardLabPanelId(key),
    name: standardPanelName(key),
    code: key,
    category: 'STANDARD',
    panel_items: testCodes.map((testCode) => {
      const definition = STANDARD_LAB_TESTS[testCode] || {};
      return {
        lab_test_id: standardLabTestId(testCode),
        test_code: definition.code || testCode
      };
    })
  })
);

const assertLabPanelUniqueness = async ({
  name,
  code,
  category,
  panelItems = [],
  tenantId,
  excludePanelId = null,
  excludePanelIds = [],
  confirmSimilar = false
}) => {
  const existingDbPanels = await labPanelRepository.findMany(
    { tenant_id: tenantId },
    0,
    7500,
    { name: 'asc' },
    LAB_PANEL_WITH_RELATIONS_INCLUDE
  );
  const duplicateCheck = mergePanelDuplicateChecks(
    checkLabPanelDuplicates({
      name,
      code,
      category,
      panelItems,
      existing: existingDbPanels,
      excludePanelId,
      excludePanelIds,
      includeTokenSimilarity: true
    }),
    checkLabPanelDuplicates({
      name,
      code,
      category,
      panelItems,
      existing: standardPanelCandidates(),
      excludePanelId,
      excludePanelIds,
      includeTokenSimilarity: false
    })
  );

  if (duplicateCheck.exactNameConflict && !confirmSimilar) {
    throw new HttpError('errors.lab_panel.duplicate_name', 409, [
      { field: 'name' }
    ]);
  }
  if (duplicateCheck.exactCodeConflict && !confirmSimilar) {
    throw new HttpError('errors.lab_panel.duplicate_code', 409, [
      { field: 'code' }
    ]);
  }
  if (
    duplicateCheck.nonExactSimilarMatches.length > 0
    && !confirmSimilar
  ) {
    throw new HttpError('errors.lab_panel.similar_exists', 409, [
      {
        field: 'name',
        matches: duplicateCheck.nonExactSimilarMatches.slice(0, 5)
      }
    ]);
  }
};

const listLabPanels = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
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

    const searchTerm = normalizeSearchTerm(filters.search);
    if (searchTerm) {
      whereClause.OR = [
        { human_friendly_id: { contains: searchTerm.upper } },
        { name: { contains: searchTerm.raw } },
        { code: { contains: searchTerm.raw } },
        { category: { contains: searchTerm.raw } },
        { description: { contains: searchTerm.raw } },
        { tenant: { human_friendly_id: { contains: searchTerm.upper } } }];
    }

    const [labPanels, total] = await Promise.all([
      labPanelRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        LAB_PANEL_WITH_RELATIONS_INCLUDE
      ),
      labPanelRepository.count(whereClause)]);
    const mappedLabPanels = labPanels.map((record) => mapLabPanelRecord(record)).filter(Boolean);
    const mergedLabPanels = mergeStandardLabPanels({
      mappedRecords: mappedLabPanels,
      filters,
      limit,
      sortBy,
      order});

    return {
      labPanels: mergedLabPanels,
      pagination: buildPagination(
        page,
        limit,
        String(filters.include_standard_catalog || '').toLowerCase() === 'true'
          ? Math.max(total, mergedLabPanels.length)
          : total
      )};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabPanelById = async (id, userId, ipAddress) => {
  try {
    const labPanel = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_panel',
      where: { deleted_at: null },
      include: LAB_PANEL_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_panel.not_found'});

    return mapLabPanelRecord(labPanel);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createLabPanel = async (data, userId, ipAddress) => {
  try {
    const confirmSimilar = data?.confirm_similar === true;
    const tenantId = await resolveModelIdOrThrow({
      identifier: data.tenant_id,
      model: 'tenant',
      where: { deleted_at: null },
      errorKey: 'errors.tenant.not_found'});
    const writeData = { ...data };
    delete writeData.confirm_similar;
    const similarityPanelItems = Array.isArray(data.panel_items)
      ? await enrichPanelItemsForSimilarity(data.panel_items, tenantId)
      : [];
    const payload = await buildPanelWritePayload(writeData, tenantId, {
      includeDeleteMany: false});
    payload.tenant_id = tenantId;

    await assertLabPanelUniqueness({
      name: payload.name ?? data.name,
      code: payload.code ?? data.code,
      category: payload.category ?? data.category,
      panelItems: similarityPanelItems,
      tenantId,
      confirmSimilar
    });

    const labPanel = await labPanelRepository.create(payload);
    const created = await labPanelRepository.findById(labPanel.id, LAB_PANEL_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'lab_panel',
      entity_id: labPanel.id,
      diff: { after: created || labPanel },
      ip_address: ipAddress}).catch(() => {});

    publishLabPanelCatalogRealtimeUpdate({
      resource: created || labPanel,
      actorUserId: userId,
      action: 'CREATED'
    });

    return mapLabPanelRecord(created || labPanel);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateLabPanel = async (id, data, userId, ipAddress) => {
  try {
    const confirmSimilar = data?.confirm_similar === true;
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_panel',
      where: { deleted_at: null },
      include: LAB_PANEL_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_panel.not_found'});

    let tenantId = before.tenant_id;
    if (Object.prototype.hasOwnProperty.call(data, 'tenant_id') && data.tenant_id) {
      tenantId = await resolveModelIdOrThrow({
        identifier: data.tenant_id,
        model: 'tenant',
        where: { deleted_at: null },
        errorKey: 'errors.tenant.not_found'});
    }
    const writeData = { ...data };
    delete writeData.confirm_similar;
    const payload = await buildPanelWritePayload(writeData, tenantId, {
      includeDeleteMany: true});
    if (hasOwn(data, 'tenant_id') && data.tenant_id) {
      payload.tenant_id = tenantId;
    }

    const nextName = hasOwn(payload, 'name') ? payload.name : before.name;
    const nextCode = hasOwn(payload, 'code') ? payload.code : before.code;
    const nextCategory = hasOwn(payload, 'category')
      ? payload.category
      : before.category;
    const nextPanelItems = hasOwn(data, 'panel_items')
      ? await enrichPanelItemsForSimilarity(data.panel_items, tenantId)
      : (before.panel_items || []).map((item) => ({
        lab_test_id: item.lab_test_id,
        test_code: item.lab_test?.code || item.test_code || null,
        lab_test: item.lab_test || null
      }));

    await assertLabPanelUniqueness({
      name: nextName,
      code: nextCode,
      category: nextCategory,
      panelItems: Array.isArray(nextPanelItems) ? nextPanelItems : [],
      tenantId,
      excludePanelId: before.id,
      excludePanelIds: [
        before.id,
        before.display_id,
        before.human_friendly_id
      ].filter(Boolean),
      confirmSimilar
    });

    const updated = await labPanelRepository.update(before.id, payload);
    const labPanel = await labPanelRepository.findById(updated.id, LAB_PANEL_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'lab_panel',
      entity_id: updated.id,
      diff: { before, after: labPanel },
      ip_address: ipAddress}).catch(() => {});

    publishLabPanelCatalogRealtimeUpdate({
      resource: labPanel || updated,
      actorUserId: userId,
      action: 'UPDATED'
    });

    return mapLabPanelRecord(labPanel || updated);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabPanel = async (id, data = {}, userId, ipAddress) => {
  try {
    const deletionReason = normalizeText(data?.reason);
    if (!deletionReason) {
      throw new HttpError('errors.validation.required', 400, [
        { field: 'reason' }]);
    }

    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_panel',
      where: { deleted_at: null },
      include: LAB_PANEL_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_panel.not_found'});

    const labPanel = await labPanelRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'lab_panel',
      entity_id: labPanel.id,
      diff: { before, deletion_reason: deletionReason },
      ip_address: ipAddress}).catch(() => {});

    publishLabPanelCatalogRealtimeUpdate({
      resource: { ...before, deleted_at: labPanel?.deleted_at || new Date() },
      actorUserId: userId,
      action: 'SOFT_DELETED'
    });

    return mapLabPanelRecord(before);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listLabPanels,
  getLabPanelById,
  createLabPanel,
  updateLabPanel,
  deleteLabPanel
};
