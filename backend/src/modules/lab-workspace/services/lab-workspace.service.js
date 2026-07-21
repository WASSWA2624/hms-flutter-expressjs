const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { normalizeIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const prisma = require('@prisma/client');
const labWorkspaceRepository = require('@repositories/lab-workspace/lab-workspace.repository');
const {
  emitToUser,
  emitToUsers,
  DIAGNOSTIC_EVENTS,
  NOTIFICATION_EVENTS} = require('@lib/websocket');
const {
  LAB_ORDER_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  toDateOrNull,
  applyDateRangeFilter} = require('@services/lab-workspace/lab.shared');
const { evaluateLabResult } = require('@services/lab-workspace/lab.interpretation');
const {
  resolveFacilityLabTestForInterpretation} = require('@services/facility-lab-catalog/facility-lab-catalog.service');
const { resolveLabRealtimeRecipients } = require('@services/lab-workspace/lab.realtime');
const {
  toPublicIdentifier,
  mapLabOrderRecord,
  mapLabOrderWorkflowRecord,
  mapLabResultRecord,
  isLabOrderPaymentSatisfied} = require('@services/lab-workspace/lab.serializer');

const ORDER_COMPLETION_STATES = new Set(['COMPLETED', 'CANCELLED']);
const SAMPLE_COLLECTABLE_STATES = new Set(['PENDING', 'COLLECTED']);
const SAMPLE_REJECTABLE_STATES = new Set(['PENDING', 'COLLECTED', 'RECEIVED']);
const RESULT_REOPENABLE_STATES = new Set(['NORMAL', 'ABNORMAL', 'CRITICAL']);
const LEGACY_ROUTE_CONFIG = Object.freeze({
  'lab-orders': {
    model: 'lab_order',
    resource: 'orders',
    route: '/lab/orders'},
  'lab-order-items': {
    model: 'lab_order_item',
    resource: 'order-items',
    route: '/lab/order-items'},
  'lab-samples': {
    model: 'lab_sample',
    resource: 'samples',
    route: '/lab/samples'},
  'lab-results': {
    model: 'lab_result',
    resource: 'results',
    route: '/lab/results'},
  'lab-tests': {
    model: 'lab_test',
    resource: 'tests',
    route: '/lab/tests'},
  'lab-panels': {
    model: 'lab_panel',
    resource: 'panels',
    route: '/lab/panels'},
  'lab-qc-logs': {
    model: 'lab_qc_log',
    resource: 'qc-logs',
    route: '/lab/qc-logs'}});
const REVERSE_STEP_PRIORITY = Object.freeze({
  COLLECT: 1,
  REJECT: 2,
  RECEIVE: 3,
  RELEASE: 4});

const LAB_ORDER_CONTEXT_PATIENT_INCLUDE = {
  contacts: {
    where: { deleted_at: null },
    orderBy: [
      { is_primary: 'desc' },
      { updated_at: 'desc' }],
    take: 3,
    select: {
      contact_type: true,
      value: true,
      is_primary: true}},
  identifiers: {
    where: { deleted_at: null },
    orderBy: [
      { is_primary: 'desc' },
      { updated_at: 'desc' }],
    take: 3,
    select: {
      identifier_type: true,
      identifier_value: true,
      is_primary: true}}};

const LAB_ORDER_CONTEXT_PATIENT_DETAIL_INCLUDE = {
  ...LAB_ORDER_CONTEXT_PATIENT_INCLUDE,
  encounters: {
    where: { deleted_at: null },
    orderBy: { started_at: 'desc' },
    take: 12,
    select: {
      id: true,
      human_friendly_id: true,
      encounter_type: true,
      status: true,
      started_at: true,
      ended_at: true}}};

const PATIENT_WORKBENCH_SCAN_LIMIT = 5000;
const WORKBENCH_VIEWS = new Set(['PATIENTS', 'ORDERS']);
const LAB_WORKBENCH_SORT_FIELDS = new Set([
  'human_friendly_id',
  'status',
  'ordered_at',
  'created_at',
  'updated_at']);

const resolveWorkbenchOrderBy = (sortBy, order = 'desc') => {
  const direction = String(order || '').trim().toLowerCase() === 'asc'
    ? 'asc'
    : 'desc';
  const field = String(sortBy || '').trim().toLowerCase();
  if (LAB_WORKBENCH_SORT_FIELDS.has(field)) {
    return { [field]: direction };
  }
  return { ordered_at: direction };
};

const normalizeWorkbenchView = (value) => {
  const normalized = String(value || 'PATIENTS').trim().toUpperCase();
  return WORKBENCH_VIEWS.has(normalized) ? normalized : 'PATIENTS';
};

const labPatientGroupKey = (order) =>
  String(order?.patient_id || order?.patient?.id || order?.id || '').trim();

const toSafeArray = (value) => (Array.isArray(value) ? value : []);

const toSafeCount = (value) => {
  const count = Number(value);
  return Number.isFinite(count) && count > 0 ? count : 0;
};

const groupLabOrdersByPatient = (records = []) => {
  const groups = new Map();
  toSafeArray(records).forEach((record) => {
    if (!record || typeof record !== 'object') return;
    const key = labPatientGroupKey(record);
    if (!key) return;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(record);
  });
  return Array.from(groups.values()).filter((group) => group.length > 0);
};

const uniqueByKey = (items, keySelector) => {
  const seen = new Set();
  return (items || []).filter((item) => {
    const key = keySelector(item);
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

const labOrderIsTerminal = (order) => ORDER_COMPLETION_STATES.has(normalizeStatus(order?.status));

const mapLabPatientWorkItem = (records = []) => {
  const mapped = toSafeArray(records)
    .map((record) => mapLabOrderRecord(record))
    .filter(Boolean);
  if (!mapped.length) return null;
  const representative = mapped[0];
  const items = uniqueByKey(mapped.flatMap((order) => order.items || []), (item) => item.id);
  const samples = uniqueByKey(mapped.flatMap((order) => order.samples || []), (sample) => sample.id);
  const statuses = mapped.map((order) => normalizeStatus(order.status)).filter(Boolean);
  const hasCritical = items.some((item) => normalizeStatus(item?.result_status) === 'CRITICAL');
  const hasRejectedItem = items.some((item) => normalizeStatus(item?.status) === 'CANCELLED');
  const hasRejectedSample = samples.some((sample) => normalizeStatus(sample?.status) === 'REJECTED');
  const activeOrders = mapped.filter((order) => !labOrderIsTerminal(order));
  const status = hasCritical
    ? 'CRITICAL'
    : hasRejectedItem
      ? 'REJECTED'
      : hasRejectedSample
        ? 'REJECTED_SAMPLE'
        : statuses.includes('IN_PROCESS')
        ? 'IN_PROCESS'
        : statuses.includes('COLLECTED')
          ? 'COLLECTED'
          : statuses.includes('ORDERED')
            ? 'ORDERED'
            : statuses.length && statuses.every((entry) => entry === 'COMPLETED')
              ? 'COMPLETED'
              : statuses.length && statuses.every((entry) => entry === 'CANCELLED')
                ? 'CANCELLED'
                : representative.status;

  const testNames = uniqueByKey(
    items.map((item) => ({ id: item?.lab_test_id || item?.test_code || item?.test_display_name, label: item?.test_display_name || item?.test_code })).filter((item) => item.label),
    (item) => item.id || item.label
  ).map((item) => item.label);
  const shownTests = testNames.slice(0, 3);
  const testsSummary = shownTests.length
    ? `${shownTests.join(', ')}${testNames.length > shownTests.length ? ` +${testNames.length - shownTests.length}` : ''}`
    : null;

  return {
    ...representative,
    patient_worklist: true,
    active_order_count: activeOrders.length,
    order_count: mapped.length,
    order_ids: mapped.map((order) => order.id).filter(Boolean),
    order_display_ids: mapped.map((order) => order.display_id || order.id).filter(Boolean),
    status,
    status_rank: Math.max(...mapped.map((order) => Number(order.status_rank || 0)), 0),
    item_count: items.length,
    pending_item_count: items.filter((item) => normalizeStatus(item?.status) === 'ORDERED').length,
    in_process_item_count: items.filter((item) => ['COLLECTED', 'IN_PROCESS'].includes(normalizeStatus(item?.status))).length,
    completed_item_count: items.filter((item) => normalizeStatus(item?.status) === 'COMPLETED').length,
    rejected_item_count: items.filter((item) => normalizeStatus(item?.status) === 'CANCELLED').length,
    sample_count: samples.length,
    tests_summary: testsSummary,
    items,
    samples};
};

const summarizeLabPatientGroups = (groups = []) => {
  const patientItems = groups.map(mapLabPatientWorkItem).filter(Boolean);
  const hasStatus = (item, values) => values.has(normalizeStatus(item.status));
  return {
    total_patients: patientItems.length,
    actionable_patients: patientItems.filter((item) => !hasStatus(item, new Set(['COMPLETED', 'CANCELLED']))).length,
    collection_patients: patientItems.filter((item) => hasStatus(item, new Set(['ORDERED', 'COLLECTED']))).length,
    processing_patients: patientItems.filter((item) => hasStatus(item, new Set(['IN_PROCESS']))).length,
    results_patients: patientItems.filter((item) => Number(item.in_process_item_count || 0) > 0).length,
    critical_patients: patientItems.filter((item) => item.items.some((entry) => normalizeStatus(entry?.result_status) === 'CRITICAL')).length,
    completed_patients: patientItems.filter((item) => hasStatus(item, new Set(['COMPLETED']))).length,
    cancelled_patients: patientItems.filter((item) => hasStatus(item, new Set(['CANCELLED']))).length,
    rejected_sample_patients: patientItems.filter((item) => item.samples.some((entry) => normalizeStatus(entry?.status) === 'REJECTED')).length};
};

const appendAnd = (where, clause) => {
  if (!clause || typeof clause !== 'object') return;
  if (!Array.isArray(where.AND)) where.AND = [];
  where.AND.push(clause);
};

const buildLabPatientRecordScope = (user = {}) => {
  const tenantId = normalizeIdentifier(user?.tenant_id || user?.tenantId);
  const facilityId = normalizeIdentifier(user?.facility_id || user?.facilityId);

  return {
    ...(tenantId ? { tenant_id: tenantId } : {}),
    ...(facilityId ? { facility_id: facilityId } : {})};
};

const buildWorkbenchPatientScope = (user = {}) => {
  const scope = buildLabPatientRecordScope(user);

  if (Object.keys(scope).length === 0) return null;

  return {
    patient: {
      deleted_at: null,
      ...scope}};
};

const normalizeEnumFilter = (value, fallback) => {
  const normalized = String(value || '').trim().toUpperCase();
  if (!normalized) return fallback;
  return normalized;
};

const assertTransition = (condition, details = {}) => {
  if (condition) return;
  throw new HttpError('errors.lab_workflow.invalid_transition', 400, [details]);
};

const normalizeStatus = (value) => String(value || '').trim().toUpperCase();

const ORDER_ITEM_RESULT_INCLUDE = Object.freeze({
  lab_test: {
    select: {
      id: true,
      unit: true,
      result_kind: true,
      reference_range: true,
      reference_ranges: {
        orderBy: { sort_order: 'asc' }},
      unit_options: {
        orderBy: { sort_order: 'asc' }},
      result_options: {
        orderBy: { sort_order: 'asc' }}}},
  lab_order: {
    select: {
      id: true,
      status: true,
      patient: {
        select: {
          id: true,
          tenant_id: true,
          facility_id: true,
          date_of_birth: true,
          gender: true}}}}});

const payloadHasField = (payload, field) =>
  Object.prototype.hasOwnProperty.call(payload || {}, field);

const toTimestampValue = (...candidates) => {
  for (const candidate of candidates) {
    if (!candidate) continue;
    const parsed = candidate instanceof Date ? candidate : new Date(candidate);
    const timestamp = parsed.getTime();
    if (Number.isFinite(timestamp)) return timestamp;
  }
  return 0;
};

const selectLatestReverseCandidate = (current, next) => {
  if (!next) return current;
  if (!current) return next;
  if (next.atMs !== current.atMs) {
    return next.atMs > current.atMs ? next : current;
  }
  const currentPriority = REVERSE_STEP_PRIORITY[current.kind] || 0;
  const nextPriority = REVERSE_STEP_PRIORITY[next.kind] || 0;
  return nextPriority >= currentPriority ? next : current;
};

const resolveRejectedSampleRestoreStatus = (sample) => {
  if (!sample || normalizeStatus(sample.status) !== 'REJECTED') return null;
  if (sample.received_at) return 'RECEIVED';
  if (sample.collected_at) return 'COLLECTED';
  return 'PENDING';
};

const resolveLatestReverseWorkflowTarget = (orderRecord) => {
  if (!orderRecord || typeof orderRecord !== 'object') return null;

  let latest = null;

  (orderRecord.items || []).forEach((item) => {
    const itemStatus = normalizeStatus(item?.status);
    if (itemStatus !== 'COMPLETED') return;

    (item?.results || []).forEach((result) => {
      const resultStatus = normalizeStatus(result?.status);
      if (!RESULT_REOPENABLE_STATES.has(resultStatus)) return;

      latest = selectLatestReverseCandidate(latest, {
        kind: 'RELEASE',
        atMs: toTimestampValue(result?.reported_at, result?.updated_at),
        orderItemId: item?.id || null,
        resultId: result?.id || null});
    });
  });

  (orderRecord.samples || []).forEach((sample) => {
    const sampleStatus = normalizeStatus(sample?.status);

    if (sampleStatus === 'RECEIVED') {
      latest = selectLatestReverseCandidate(latest, {
        kind: 'RECEIVE',
        atMs: toTimestampValue(sample?.received_at, sample?.updated_at),
        sampleId: sample?.id || null});
      return;
    }

    if (sampleStatus === 'REJECTED') {
      latest = selectLatestReverseCandidate(latest, {
        kind: 'REJECT',
        atMs: toTimestampValue(sample?.updated_at, sample?.received_at, sample?.collected_at),
        sampleId: sample?.id || null});
      return;
    }

    if (sampleStatus === 'COLLECTED') {
      latest = selectLatestReverseCandidate(latest, {
        kind: 'COLLECT',
        atMs: toTimestampValue(sample?.collected_at, sample?.updated_at),
        sampleId: sample?.id || null});
    }
  });

  return latest;
};

const syncLabOrderProgress = async (tx, orderId) => {
  const receivedSamples = await labWorkspaceRepository.txCountSamples(tx, {
    lab_order_id: orderId,
    status: 'RECEIVED'});
  const collectedSamples = await labWorkspaceRepository.txCountSamples(tx, {
    lab_order_id: orderId,
    status: 'COLLECTED'});
  const completedItems = await labWorkspaceRepository.txCountOrderItems(tx, {
    lab_order_id: orderId,
    status: 'COMPLETED'});
  const cancelledItems = await labWorkspaceRepository.txCountOrderItems(tx, {
    lab_order_id: orderId,
    status: 'CANCELLED'});
  const openItems = await labWorkspaceRepository.txCountOrderItems(tx, {
    lab_order_id: orderId,
    status: { notIn: ['COMPLETED', 'CANCELLED'] }});

  let nextActiveItemStatus = 'ORDERED';
  if (receivedSamples > 0 || completedItems > 0) {
    nextActiveItemStatus = 'IN_PROCESS';
  } else if (collectedSamples > 0) {
    nextActiveItemStatus = 'COLLECTED';
  }

  if (openItems > 0) {
    await labWorkspaceRepository.txUpdateOrderItemsMany(
      tx,
      {
        lab_order_id: orderId,
        status: { notIn: ['COMPLETED', 'CANCELLED'] }},
      { status: nextActiveItemStatus }
    );
  }

  const nextOrderStatus = openItems === 0
    ? completedItems > 0
      ? 'COMPLETED'
      : cancelledItems > 0
        ? 'CANCELLED'
        : 'ORDERED'
    : nextActiveItemStatus;

  await labWorkspaceRepository.txUpdateOrder(tx, orderId, {
    status: nextOrderStatus});

  return {
    nextOrderStatus,
    nextActiveItemStatus,
    completedItems,
    cancelledItems,
    openItems};
};


const buildWorkbenchOrderWhere = async (filters = {}, options = {}) => {
  const includeSearch = options.includeSearch !== false;
  const where = {};

  appendAnd(where, buildWorkbenchPatientScope(options.user));
  appendAnd(where, {
    items: {
      some: {
        deleted_at: null,
        status: { not: 'CANCELLED' }}}});

  if (filters.patient_id) {
    where.patient_id = await resolveModelIdOrThrow({
      identifier: filters.patient_id,
      model: 'patient',
      where: { deleted_at: null },
      errorKey: 'errors.patient.not_found'});
  }

  if (filters.encounter_id) {
    where.encounter_id = await resolveModelIdOrThrow({
      identifier: filters.encounter_id,
      model: 'encounter',
      where: { deleted_at: null },
      errorKey: 'errors.encounter.not_found'});
  }

  if (filters.status) {
    where.status = filters.status;
  }

  applyDateRangeFilter(where, 'ordered_at', filters.from, filters.to);

  const stage = normalizeEnumFilter(filters.stage, 'ALL');
  if (stage === 'COLLECTION') {
    appendAnd(where, { status: { in: ['ORDERED', 'COLLECTED'] } });
  } else if (stage === 'PROCESSING') {
    appendAnd(where, { status: 'IN_PROCESS' });
  } else if (stage === 'RESULTS') {
    appendAnd(where, {
      items: {
        some: {
          deleted_at: null,
          OR: [
            { status: { in: ['COLLECTED', 'IN_PROCESS'] } },
            { results: { some: { deleted_at: null, status: 'PENDING' } } }]}}});
  } else if (stage === 'COMPLETED') {
    appendAnd(where, { status: 'COMPLETED' });
  } else if (stage === 'CANCELLED') {
    appendAnd(where, { status: 'CANCELLED' });
  }

  const criticality = normalizeEnumFilter(filters.criticality, 'ALL');
  if (criticality === 'CRITICAL') {
    appendAnd(where, {
      items: {
        some: {
          deleted_at: null,
          results: {
            some: {
              deleted_at: null,
              status: 'CRITICAL'}}}}});
  } else if (criticality === 'NON_CRITICAL') {
    appendAnd(where, {
      items: {
        none: {
          deleted_at: null,
          results: {
            some: {
              deleted_at: null,
              status: 'CRITICAL'}}}}});
  }

  const searchTerm = normalizeSearchTerm(filters.search);
  if (includeSearch && searchTerm) {
    appendAnd(where, {
      OR: [
        { human_friendly_id: { contains: searchTerm.upper } },
        { patient: { human_friendly_id: { contains: searchTerm.upper } } },
        { patient: { first_name: { contains: searchTerm.raw } } },
        { patient: { last_name: { contains: searchTerm.raw } } },
        { encounter: { human_friendly_id: { contains: searchTerm.upper } } },
        { samples: { some: { human_friendly_id: { contains: searchTerm.upper } } } },
        { items: { some: { human_friendly_id: { contains: searchTerm.upper } } } },
        { items: { some: { lab_test: { human_friendly_id: { contains: searchTerm.upper } } } } },
        { items: { some: { lab_test: { name: { contains: searchTerm.raw } } } } },
        { items: { some: { lab_test: { code: { contains: searchTerm.raw } } } } },
        { items: { some: { results: { some: { human_friendly_id: { contains: searchTerm.upper } } } } } }]});
  }

  return where;
};

const toText = (value) => (value == null ? '' : String(value).trim());

const firstNonEmpty = (...values) => {
  for (const value of values) {
    const normalized = toText(value);
    if (normalized) return normalized;
  }
  return null;
};

const primaryContactValue = (patient, contactType) => {
  const contacts = Array.isArray(patient?.contacts) ? patient.contacts : [];
  const preferred = contacts.find(
    (entry) =>
      toText(entry?.contact_type).toUpperCase() === contactType &&
      entry?.is_primary
  );
  const fallback = contacts.find(
    (entry) => toText(entry?.contact_type).toUpperCase() === contactType
  );
  return firstNonEmpty(preferred?.value, fallback?.value);
};

const primaryIdentifierValue = (patient) => {
  const identifiers = Array.isArray(patient?.identifiers) ? patient.identifiers : [];
  const preferred = identifiers.find((entry) => entry?.is_primary);
  return firstNonEmpty(preferred?.identifier_value, identifiers[0]?.identifier_value);
};

const mapLabOrderContextPatient = (patient) => {
  if (!patient || typeof patient !== 'object') return null;
  const publicId = toPublicIdentifier(patient.human_friendly_id, patient.id);
  const id = firstNonEmpty(publicId, patient.id);
  if (!id) return null;

  return {
    id,
    display_id: publicId,
    display_name: firstNonEmpty(
      [patient.first_name, patient.last_name].map(toText).filter(Boolean).join(' '),
      publicId,
      patient.id
    ),
    identifier: primaryIdentifierValue(patient),
    primary_phone: primaryContactValue(patient, 'PHONE')};
};

const mapLabOrderContextEncounter = (encounter) => {
  if (!encounter || typeof encounter !== 'object') return null;
  const publicId = toPublicIdentifier(encounter.human_friendly_id, encounter.id);
  const id = firstNonEmpty(publicId, encounter.id);
  if (!id) return null;

  return {
    id,
    display_id: publicId,
    title: firstNonEmpty(publicId, encounter.id),
    status: firstNonEmpty(encounter.status),
    type: firstNonEmpty(encounter.encounter_type),
    started_at: encounter.started_at || null,
    ended_at: encounter.ended_at || null};
};

const buildLabOrderContextPatientWhere = (filters = {}, user = {}) => {
  const where = buildLabPatientRecordScope(user);
  const searchTerm = normalizeSearchTerm(filters.search);
  if (!searchTerm) return where;

  where.OR = [
    { human_friendly_id: { contains: searchTerm.upper } },
    { first_name: { contains: searchTerm.raw } },
    { last_name: { contains: searchTerm.raw } },
    {
      identifiers: {
        some: {
          deleted_at: null,
          identifier_value: { contains: searchTerm.raw }}}},
    {
      contacts: {
        some: {
          deleted_at: null,
          value: { contains: searchTerm.raw }}}}];

  return where;
};

const searchLabOrderContextPatients = async (filters = {}, user = {}) => {
  try {
    const limit = Math.min(Math.max(Number(filters.limit) || 8, 1), 25);
    const where = buildLabOrderContextPatientWhere(filters, user);
    const patients = await labWorkspaceRepository.findManyPatients(
      where,
      0,
      limit,
      [{ updated_at: 'desc' }, { created_at: 'desc' }],
      LAB_ORDER_CONTEXT_PATIENT_INCLUDE
    );

    return {
      patients: (patients || [])
        .map(mapLabOrderContextPatient)
        .filter(Boolean)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabOrderPatientContext = async (patientId, user = {}) => {
  try {
    const normalized = normalizeIdentifier(patientId);
    if (!normalized) {
      throw new HttpError('errors.patient.not_found', 404);
    }

    const patient = await labWorkspaceRepository.findPatientById(
      normalized,
      buildLabPatientRecordScope(user),
      LAB_ORDER_CONTEXT_PATIENT_DETAIL_INCLUDE
    );
    if (!patient) {
      throw new HttpError('errors.patient.not_found', 404);
    }

    return {
      patient: mapLabOrderContextPatient(patient),
      encounters: (patient.encounters || [])
        .map(mapLabOrderContextEncounter)
        .filter(Boolean)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const mapReleasedResultFromOrder = (orderRecord, releasedResultId) => {
  if (!orderRecord || !releasedResultId) return null;
  for (const item of orderRecord.items || []) {
    for (const result of item.results || []) {
      if (result.id === releasedResultId) {
        return mapLabResultRecord({
          ...result,
          lab_order_item: item});
      }
    }
  }
  return null;
};

const mapReleasedResultsFromOrder = (orderRecord, releasedResultIds = []) => {
  const ids = new Set((releasedResultIds || []).filter(Boolean));
  if (!ids.size) return [];
  const results = [];
  for (const item of orderRecord?.items || []) {
    for (const result of item?.results || []) {
      if (!ids.has(result.id)) continue;
      const mapped = mapLabResultRecord({
        ...result,
        lab_order_item: item});
      if (mapped) results.push(mapped);
    }
  }
  return results;
};

const resolveTargetLabResult = async (tx, item, payload = {}) => {
  if (payload.result_id) {
    const resultId = await resolveModelIdOrThrow({
      identifier: payload.result_id,
      model: 'lab_result',
      where: { deleted_at: null, lab_order_item_id: item.id },
      errorKey: 'errors.lab_result.not_found'});
    return labWorkspaceRepository.txFindResultById(tx, resultId);
  }

  const pendingResult = await labWorkspaceRepository.txFindFirstResult(tx, {
    lab_order_item_id: item.id,
    status: 'PENDING'});
  if (pendingResult) return pendingResult;

  return labWorkspaceRepository.txFindFirstResult(
    tx,
    { lab_order_item_id: item.id },
    { created_at: 'desc' }
  );
};

const persistLabOrderItemResult = async (tx, item, payload = {}) => {
  assertTransition(item.status !== 'CANCELLED', {
    from: item.status,
    to: 'COMPLETED'});

  const targetResult = await resolveTargetLabResult(tx, item, payload);
  const fallbackStatus =
    targetResult?.status && targetResult.status !== 'PENDING'
      ? targetResult.status
      : 'NORMAL';
  const resultData = {
    status: fallbackStatus,
    result_value: payloadHasField(payload, 'result_value')
      ? payload.result_value
      : targetResult?.result_value || null,
    result_unit: payloadHasField(payload, 'result_unit')
      ? payload.result_unit
      : targetResult?.result_unit || item?.lab_test?.unit || null,
    result_text: payloadHasField(payload, 'result_text')
      ? payload.result_text
      : targetResult?.result_text || null,
    reported_at: toDateOrNull(payload.reported_at, new Date())};

  const patient = item?.lab_order?.patient || {};
  const resolvedTest = await resolveFacilityLabTestForInterpretation({
    tenantId: patient.tenant_id,
    facilityId: patient.facility_id,
    labTestId: item?.lab_test_id || item?.lab_test?.id,
    masterTest: item?.lab_test || {}});

  const interpretation = evaluateLabResult({
    test: resolvedTest || item?.lab_test || {},
    patient,
    resultValue: resultData.result_value,
    resultText: resultData.result_text,
    resultUnit: resultData.result_unit,
    fallbackStatus});

  resultData.status = interpretation.status;
  resultData.result_unit = interpretation.result_unit || null;
  resultData.result_flag = interpretation.result_flag || null;
  resultData.is_positive = Boolean(interpretation.is_positive);
  resultData.reference_range_label = interpretation.reference_range_label || null;
  resultData.reference_range_summary = interpretation.reference_range_summary || null;
  resultData.applied_reference_range_id = interpretation.applied_reference_range_id || null;
  resultData.applied_reference_range_json =
    interpretation.applied_reference_range_json || null;

  const releasedResult = targetResult
    ? await labWorkspaceRepository.txUpdateResult(tx, targetResult.id, resultData)
    : await labWorkspaceRepository.txCreateResult(tx, {
        ...resultData,
        lab_order_item_id: item.id});

  await labWorkspaceRepository.txUpdateOrderItem(tx, item.id, {
    status: 'COMPLETED',
    rejection_reason: null,
    rejection_notes: null,
    rejected_at: null});

  return releasedResult;
};

const resolveAuditTenantId = (orderRecord) =>
  String(orderRecord?.patient?.tenant_id || '').trim() || null;

const resolveRoleRecipients = async ({ tenantId, facilityId = null, orderRecord = null, actorUserId = null }) => {
  if (!tenantId) return [];
  return resolveLabRealtimeRecipients({
    orderRecord: orderRecord || { patient: { tenant_id: tenantId, facility_id: facilityId } },
    actorUserId});
};

const buildLabRealtimePayload = ({
  workflow,
  action,
  resourceType = null,
  resourceId = null}) => {
  const order = workflow?.order || null;
  const orderId = String(order?.id || '').trim() || null;
  const patientId = String(order?.patient_id || '').trim() || null;
  const nowIso = new Date().toISOString();

  return {
    order_id: orderId,
    order_public_id: orderId,
    patient_id: patientId,
    patient_public_id: patientId,
    patient_display_name: order?.patient_display_name || null,
    status: order?.status || null,
    action: String(action || 'UPDATED').trim().toUpperCase(),
    resource_type: resourceType,
    resource_id: resourceId,
    occurred_at: nowIso,
    target_path: orderId ? `/lab?id=${encodeURIComponent(orderId)}` : '/lab',
    workflow};
};

const buildLabPatientDisplayName = (orderRecord) => {
  const patient = orderRecord?.patient || {};
  const name = [patient.first_name, patient.last_name]
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .join(' ')
    .trim();
  return name || null;
};

const resolveCriticalNotificationRecipients = (orderRecord, actorUserId = null) => {
  const ids = [
    orderRecord?.ordered_by_user_id,
    orderRecord?.ordered_by?.id,
    orderRecord?.encounter?.provider_user_id]
    .map((value) => String(value || '').trim())
    .filter(Boolean);
  const unique = [...new Set(ids)];
  return actorUserId ? unique.filter((id) => id && id !== actorUserId) : unique;
};

/**
 * Critical lab result escalation.
 *
 * When a CRITICAL result is released/verified, the ordering doctor and the
 * encounter provider (ward/OPD) must be alerted out-of-band — beyond the generic
 * workflow refresh — per ipd-flow §17. We emit a dedicated realtime event and
 * persist HIGH-priority in-app notifications so the alert survives reconnects.
 */
const notifyCriticalLabResults = async ({
  orderRecord,
  releasedResults = [],
  actorUserId = null}) => {
  try {
    const criticalResults = (Array.isArray(releasedResults) ? releasedResults : [])
      .filter((result) => normalizeStatus(result?.status) === 'CRITICAL');
    if (!criticalResults.length) return;

    const tenantId = String(orderRecord?.patient?.tenant_id || '').trim() || null;
    if (!tenantId) return;

    const recipients = resolveCriticalNotificationRecipients(orderRecord, actorUserId);
    if (!recipients.length) return;

    const orderPublicId =
      toPublicIdentifier(orderRecord?.human_friendly_id, orderRecord?.id) || null;
    const patientPublicId =
      toPublicIdentifier(orderRecord?.patient?.human_friendly_id, orderRecord?.patient_id) || null;
    const patientName = buildLabPatientDisplayName(orderRecord);
    const testNames = [
      ...new Set(
        criticalResults
          .map((result) => String(result?.test_display_name || result?.test_code || '').trim())
          .filter(Boolean)
      )];
    const targetPath = orderPublicId
      ? `/lab?id=${encodeURIComponent(orderPublicId)}`
      : '/lab';
    const subject = patientName || patientPublicId || 'patient';
    const testSummary = testNames.length ? ` (${testNames.slice(0, 4).join(', ')})` : '';
    const title = 'Critical lab result';
    const message = `Critical lab result for ${subject}${testSummary} requires review.`;

    const realtimePayload = {
      order_id: orderPublicId,
      order_public_id: orderPublicId,
      patient_id: patientPublicId,
      patient_public_id: patientPublicId,
      patient_display_name: patientName,
      critical_count: criticalResults.length,
      test_names: testNames,
      action: 'CRITICAL',
      occurred_at: new Date().toISOString(),
      target_path: targetPath};

    if (DIAGNOSTIC_EVENTS?.LAB_RESULT_CRITICAL) {
      emitToUsers(recipients, DIAGNOSTIC_EVENTS.LAB_RESULT_CRITICAL, realtimePayload);
    }

    if (!prisma?.notification?.create) return;

    for (const userId of recipients) {
      try {
        const notification = await prisma.notification.create({
          data: {
            tenant_id: tenantId,
            user_id: userId,
            notification_type: 'LAB',
            priority: 'URGENT',
            title,
            message,
            target_path: targetPath,
            context_type: 'lab_order',
            context_public_id: orderPublicId}});

        if (prisma?.notification_delivery?.create) {
          await prisma.notification_delivery
            .create({
              data: {
                notification_id: notification.id,
                channel: 'IN_APP',
                status: 'SENT',
                sent_at: new Date()}})
            .catch(() => {});
        }

        if (typeof emitToUser === 'function' && NOTIFICATION_EVENTS?.NOTIFICATION_CREATED) {
          emitToUser(notification.user_id, NOTIFICATION_EVENTS.NOTIFICATION_CREATED, {
            notification: {
              id: notification.human_friendly_id || notification.id,
              notification_type: notification.notification_type,
              priority: notification.priority,
              title: notification.title,
              message: notification.message,
              target_path: notification.target_path,
              created_at: notification.created_at},
            target_path: targetPath});
        }
      } catch (_notificationError) {
        // A single failed notification must not abort the remaining recipients.
      }
    }
  } catch (_error) {
    // Critical escalation must never block lab workflow updates.
  }
};

const publishLabRealtimeUpdates = async ({
  workflow,
  orderRecord,
  actorUserId = null,
  action,
  resourceType = null,
  resourceId = null,
  releasedResult = null,
  releasedResults = null}) => {
  try {
    const criticalCandidates = Array.isArray(releasedResults) && releasedResults.length
      ? releasedResults
      : releasedResult
        ? [releasedResult]
        : [];
    notifyCriticalLabResults({
      orderRecord,
      releasedResults: criticalCandidates,
      actorUserId}).catch(() => {});

    const tenantId = orderRecord?.patient?.tenant_id || null;
    if (!tenantId) return;

    const facilityId = orderRecord?.patient?.facility_id || null;
    const recipientUserIds = await resolveRoleRecipients({
      tenantId,
      facilityId,
      orderRecord,
      actorUserId});

    const recipients = recipientUserIds.filter(Boolean);
    if (!recipients.length) return;

    const workflowPayload = buildLabRealtimePayload({
      workflow,
      action,
      resourceType,
      resourceId});

    emitToUsers(
      recipients,
      DIAGNOSTIC_EVENTS.LAB_WORKFLOW_UPDATED,
      workflowPayload
    );

    if (!releasedResult) return;

    const resultStatus = String(releasedResult.status || '')
      .trim()
      .toUpperCase();
    const compatibilityPayload = {
      order_id: workflowPayload.order_id,
      order_public_id: workflowPayload.order_public_id,
      patient_id: workflowPayload.patient_id,
      patient_public_id: workflowPayload.patient_public_id,
      result_id: releasedResult.id || null,
      result_public_id: releasedResult.id || null,
      result_status: resultStatus || null,
      action: workflowPayload.action,
      occurred_at: workflowPayload.occurred_at,
      target_path: releasedResult.id
        ? `/lab/results/${encodeURIComponent(releasedResult.id)}`
        : workflowPayload.target_path};

    emitToUsers(
      recipients,
      DIAGNOSTIC_EVENTS.LAB_RESULT_UPDATED,
      compatibilityPayload
    );

    if (resultStatus && resultStatus !== 'PENDING') {
      emitToUsers(
        recipients,
        DIAGNOSTIC_EVENTS.LAB_RESULT_READY,
        compatibilityPayload
      );
    }
  } catch (_error) {
    // realtime should never block lab workflow updates
  }
};

/**
 * Hand off to the OPD orchestrator after a lab workflow mutation so the encounter
 * can advance out of `LAB_REQUESTED` / `LAB_AND_RADIOLOGY_REQUESTED` once lab work
 * is done. Lab never mutates OPD stages itself — it only signals completion. The
 * call is fire-and-forget and a safe no-op for IPD orders (no OPD flow resolves).
 */
const syncOpdFlowForOrder = (orderRecord, { userId = null, trigger = 'LAB_WORKFLOW_UPDATED' } = {}) => {
  const encounterId = String(
    orderRecord?.encounter_id || orderRecord?.encounter?.id || ''
  ).trim();
  if (!encounterId) return;

  try {
    const opdFlowService = require('@services/opd-flow/opd-flow.service');
    if (typeof opdFlowService.syncDiagnosticsStage !== 'function') return;
    Promise.resolve(
      opdFlowService.syncDiagnosticsStage(encounterId, {
        user_id: userId || null,
        trigger})
    ).catch(() => {});
  } catch (_error) {
    // OPD orchestration must never block lab workflow updates.
  }
};

const getLabWorkbench = async (filters, page, limit, sortBy, order, user = {}) => {
  try {
    const view = normalizeWorkbenchView(filters?.view);
    const skip = (page - 1) * limit;
    const orderBy = resolveWorkbenchOrderBy(sortBy, order);

    const [where, summaryWhere] = await Promise.all([
      buildWorkbenchOrderWhere(filters, { includeSearch: true, user }),
      buildWorkbenchOrderWhere(filters, { includeSearch: false, user })]);

    const [
      orderWorklistRecords,
      total,
      totalOrders,
      collectionQueue,
      processingQueue,
      completedOrders,
      cancelledOrders,
      resultsQueue,
      criticalResults,
      rejectedSamples,
      summaryOrderRecords] = await Promise.all([
      view === 'PATIENTS'
        ? labWorkspaceRepository.findManyOrders(
            where,
            0,
            PATIENT_WORKBENCH_SCAN_LIMIT,
            orderBy,
            LAB_ORDER_WITH_RELATIONS_INCLUDE
          )
        : labWorkspaceRepository.findManyOrders(
            where,
            skip,
            limit,
            orderBy,
            LAB_ORDER_WITH_RELATIONS_INCLUDE
          ),
      view === 'PATIENTS'
        ? Promise.resolve(0)
        : labWorkspaceRepository.countOrders(where),
      labWorkspaceRepository.countOrders(summaryWhere),
      labWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: { in: ['ORDERED', 'COLLECTED'] }}),
      labWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'IN_PROCESS'}),
      labWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'COMPLETED'}),
      labWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'CANCELLED'}),
      labWorkspaceRepository.countOrderItems({
        status: { in: ['COLLECTED', 'IN_PROCESS'] },
        lab_order: {
          deleted_at: null,
          ...summaryWhere}}),
      labWorkspaceRepository.countResults({
        status: 'CRITICAL',
        lab_order_item: {
          deleted_at: null,
          lab_order: {
            deleted_at: null,
            ...summaryWhere}}}),
      labWorkspaceRepository.countSamples({
        status: 'REJECTED',
        lab_order: {
          deleted_at: null,
          ...summaryWhere}}),
      labWorkspaceRepository.findManyOrders(
        summaryWhere,
        0,
        PATIENT_WORKBENCH_SCAN_LIMIT,
        orderBy,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      )]);

    const worklistRecords = toSafeArray(orderWorklistRecords);
    const summaryRecords = toSafeArray(summaryOrderRecords);
    const patientGroups = groupLabOrdersByPatient(worklistRecords);
    const patientSummary = summarizeLabPatientGroups(
      groupLabOrdersByPatient(summaryRecords)
    );
    const patientWorklist = patientGroups.map(mapLabPatientWorkItem).filter(Boolean);
    const pagedPatientWorklist = patientWorklist.slice(skip, skip + limit);
    const worklist = view === 'PATIENTS'
      ? pagedPatientWorklist
      : worklistRecords.map((record) => mapLabOrderRecord(record)).filter(Boolean);
    const worklistTotal = view === 'PATIENTS'
      ? patientWorklist.length
      : toSafeCount(total);

    return {
      summary: {
        view: view.toLowerCase(),
        total_orders: toSafeCount(totalOrders),
        collection_queue: toSafeCount(collectionQueue),
        processing_queue: toSafeCount(processingQueue),
        results_queue: toSafeCount(resultsQueue),
        critical_results: toSafeCount(criticalResults),
        completed_orders: toSafeCount(completedOrders),
        cancelled_orders: toSafeCount(cancelledOrders),
        rejected_samples: toSafeCount(rejectedSamples),
        ...patientSummary},
      worklist,
      pagination: buildPagination(page, limit, worklistTotal)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabOrderWorkflow = async (identifier) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order.not_found'});

    const orderRecord = await labWorkspaceRepository.findOrderById(
      orderId,
      LAB_ORDER_WITH_RELATIONS_INCLUDE
    );
    if (!orderRecord) {
      throw new HttpError('errors.lab_order.not_found', 404);
    }

    return mapLabOrderWorkflowRecord(orderRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const collectLabOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order.not_found'});

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const order = await labWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.lab_order.not_found', 404);
      }

      if (!isLabOrderPaymentSatisfied(order)) {
        throw new HttpError('errors.lab_order.payment_required', 402, [
          {
            field: 'payment_status',
            payment_status: order?.billing_snapshot?.payment_status || null}]);
      }

      assertTransition(!ORDER_COMPLETION_STATES.has(order.status), {
        from: order.status,
        to: 'COLLECTED'});

      const collectedAt = toDateOrNull(payload.collected_at, new Date());
      let targetSample = null;

      if (payload.sample_id) {
        const sampleId = await resolveModelIdOrThrow({
          identifier: payload.sample_id,
          model: 'lab_sample',
          where: { deleted_at: null, lab_order_id: order.id },
          errorKey: 'errors.lab_sample.not_found'});
        targetSample = await labWorkspaceRepository.txFindSampleById(tx, sampleId);
        if (!targetSample || targetSample.lab_order_id !== order.id) {
          throw new HttpError('errors.lab_sample.not_found', 404);
        }
        assertTransition(SAMPLE_COLLECTABLE_STATES.has(targetSample.status), {
          from: targetSample.status,
          to: 'COLLECTED'});
      } else {
        const existing = (order.samples || []).find((sample) =>
          SAMPLE_COLLECTABLE_STATES.has(sample.status)
        );
        if (existing) {
          targetSample = await labWorkspaceRepository.txFindSampleById(tx, existing.id);
        }
      }

      if (targetSample) {
        targetSample = await labWorkspaceRepository.txUpdateSample(tx, targetSample.id, {
          status: 'COLLECTED',
          collected_at: collectedAt,
          rejection_reason: null,
          rejection_notes: null,
          rejected_at: null});
      } else {
        targetSample = await labWorkspaceRepository.txCreateSample(tx, {
          lab_order_id: order.id,
          status: 'COLLECTED',
          collected_at: collectedAt});
      }

      await labWorkspaceRepository.txUpdateOrderItemsMany(
        tx,
        { lab_order_id: order.id, status: 'ORDERED' },
        { status: 'COLLECTED' }
      );

      if (order.status === 'ORDERED') {
        await labWorkspaceRepository.txUpdateOrder(tx, order.id, { status: 'COLLECTED' });
      }

      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder,
        sampleId: targetSample.id};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'COLLECT',
      entity: 'lab_order',
      entity_id: orderId,
      diff: {
        metadata: {
          before_status: mutation.beforeStatus,
          after_status: mutation.order?.status,
          sample_id: mutation.sampleId,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'COLLECT',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const receiveLabSample = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const sampleId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_sample',
      where: { deleted_at: null },
      errorKey: 'errors.lab_sample.not_found'});

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const sample = await labWorkspaceRepository.txFindSampleById(tx, sampleId);
      if (!sample) {
        throw new HttpError('errors.lab_sample.not_found', 404);
      }

      assertTransition(sample.status !== 'REJECTED', {
        from: sample.status,
        to: 'RECEIVED'});

      const receivedAt = toDateOrNull(payload.received_at, new Date());
      await labWorkspaceRepository.txUpdateSample(tx, sample.id, {
        status: 'RECEIVED',
        received_at: receivedAt});

      const order = await labWorkspaceRepository.txFindOrderById(
        tx,
        sample.lab_order_id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.lab_order.not_found', 404);
      }

      if (!ORDER_COMPLETION_STATES.has(order.status)) {
        await labWorkspaceRepository.txUpdateOrder(tx, order.id, { status: 'IN_PROCESS' });
      }

      await labWorkspaceRepository.txUpdateOrderItemsMany(
        tx,
        {
          lab_order_id: order.id,
          status: { in: ['ORDERED', 'COLLECTED'] }},
        { status: 'IN_PROCESS' }
      );

      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'RECEIVE',
      entity: 'lab_sample',
      entity_id: sampleId,
      diff: {
        metadata: {
          before_order_status: mutation.beforeStatus,
          after_order_status: mutation.order?.status,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'RECEIVE',
      resourceType: 'sample',
      resourceId: identifier}).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const rejectLabSample = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const sampleId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_sample',
      where: { deleted_at: null },
      errorKey: 'errors.lab_sample.not_found'});

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const sample = await labWorkspaceRepository.txFindSampleById(tx, sampleId);
      if (!sample) {
        throw new HttpError('errors.lab_sample.not_found', 404);
      }

      assertTransition(SAMPLE_REJECTABLE_STATES.has(sample.status), {
        from: sample.status,
        to: 'REJECTED'});

      await labWorkspaceRepository.txUpdateSample(tx, sample.id, {
        status: 'REJECTED',
        rejection_reason: toText(payload.reason) || null,
        rejection_notes: toText(payload.notes) || null,
        rejected_at: toDateOrNull(payload.rejected_at, new Date())});

      const order = await labWorkspaceRepository.txFindOrderById(
        tx,
        sample.lab_order_id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.lab_order.not_found', 404);
      }

      const activeSamples = await labWorkspaceRepository.txCountSamples(tx, {
        lab_order_id: order.id,
        status: { in: ['PENDING', 'COLLECTED', 'RECEIVED'] }});

      if (activeSamples === 0 && !ORDER_COMPLETION_STATES.has(order.status)) {
        await labWorkspaceRepository.txUpdateOrder(tx, order.id, { status: 'ORDERED' });
        await labWorkspaceRepository.txUpdateOrderItemsMany(
          tx,
          {
            lab_order_id: order.id,
            status: { in: ['COLLECTED', 'IN_PROCESS'] }},
          { status: 'ORDERED' }
        );
      }

      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'REJECT',
      entity: 'lab_sample',
      entity_id: sampleId,
      diff: {
        metadata: {
          reason: payload.reason || null,
          notes: payload.notes || null,
          before_order_status: mutation.beforeStatus,
          after_order_status: mutation.order?.status}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'REJECT',
      resourceType: 'sample',
      resourceId: identifier}).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const releaseLabOrderItem = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderItemId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order_item',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order_item.not_found'});

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const item = await labWorkspaceRepository.txFindOrderItemById(
        tx,
        orderItemId,
        ORDER_ITEM_RESULT_INCLUDE
      );
      if (!item) {
        throw new HttpError('errors.lab_order_item.not_found', 404);
      }

      const releasedResult = await persistLabOrderItemResult(tx, item, payload);
      const progress = await syncLabOrderProgress(tx, item.lab_order_id);
      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        item.lab_order_id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeItemStatus: item.status,
        beforeOrderStatus: item.lab_order?.status || null,
        order: refreshedOrder,
        progress,
        releasedResultId: releasedResult.id};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'VERIFY_RESULT',
      entity: 'lab_order_item',
      entity_id: orderItemId,
      diff: {
        metadata: {
          before_item_status: mutation.beforeItemStatus,
          after_order_status: mutation.order?.status || null,
          before_order_status: mutation.beforeOrderStatus,
          released_result_id: mutation.releasedResultId,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    const releasedResult = mapReleasedResultFromOrder(
      mutation.order,
      mutation.releasedResultId
    );
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'VERIFY_RESULT',
      resourceType: 'order-item',
      resourceId: identifier,
      releasedResult}).catch(() => {});
    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'LAB_RESULT_RELEASED'});

    return {
      workflow,
      released_result: releasedResult};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const verifyLabOrderResults = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order.not_found'});

    const resultPayloads = Array.isArray(payload.results) ? payload.results : [];
    if (!resultPayloads.length) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'results' }]);
    }

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const order = await labWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.lab_order.not_found', 404);
      }

      const releasedResultIds = [];
      const itemTransitions = [];
      for (const entry of resultPayloads) {
        const orderItemId = await resolveModelIdOrThrow({
          identifier: entry.order_item_id,
          model: 'lab_order_item',
          where: { deleted_at: null, lab_order_id: order.id },
          errorKey: 'errors.lab_order_item.not_found'});
        const item = await labWorkspaceRepository.txFindOrderItemById(
          tx,
          orderItemId,
          ORDER_ITEM_RESULT_INCLUDE
        );
        if (!item || item.lab_order_id !== order.id) {
          throw new HttpError('errors.lab_order_item.not_found', 404);
        }

        const releasedResult = await persistLabOrderItemResult(tx, item, entry);
        releasedResultIds.push(releasedResult.id);
        itemTransitions.push({
          order_item_id: item.id,
          before_status: item.status,
          released_result_id: releasedResult.id});
      }

      const progress = await syncLabOrderProgress(tx, order.id);
      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeOrderStatus: order.status,
        order: refreshedOrder,
        progress,
        releasedResultIds,
        itemTransitions};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'VERIFY_RESULTS',
      entity: 'lab_order',
      entity_id: orderId,
      diff: {
        metadata: {
          before_order_status: mutation.beforeOrderStatus,
          after_order_status: mutation.order?.status || null,
          item_transitions: mutation.itemTransitions}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    const releasedResults = mapReleasedResultsFromOrder(
      mutation.order,
      mutation.releasedResultIds
    );
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'VERIFY_RESULTS',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
      releasedResult: releasedResults[0] || null,
      releasedResults}).catch(() => {});
    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'LAB_RESULTS_VERIFIED'});

    return {
      workflow,
      released_results: releasedResults};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const rejectLabOrderItem = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const reason = String(payload?.reason || '').trim();
    if (!reason) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'reason' }]);
    }

    const orderItemId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order_item',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order_item.not_found'});

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const item = await labWorkspaceRepository.txFindOrderItemById(tx, orderItemId, {
        lab_order: { select: { id: true, status: true } }});
      if (!item) {
        throw new HttpError('errors.lab_order_item.not_found', 404);
      }
      assertTransition(item.status !== 'COMPLETED', {
        from: item.status,
        to: 'CANCELLED'});

      const remainingActiveItems = await labWorkspaceRepository.txCountOrderItems(tx, {
        lab_order_id: item.lab_order_id,
        id: { not: item.id },
        status: { not: 'CANCELLED' }});
      if (remainingActiveItems === 0) {
        throw new HttpError('errors.lab_order.at_least_one_active_test_required', 409, [
          { field: 'lab_order_item_id' }]);
      }

      await labWorkspaceRepository.txUpdateOrderItem(tx, item.id, {
        status: 'CANCELLED',
        rejection_reason: reason,
        rejection_notes: payload.notes || null,
        rejected_at: toDateOrNull(payload.rejected_at, new Date())});
      const progress = await syncLabOrderProgress(tx, item.lab_order_id);
      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        item.lab_order_id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeItemStatus: item.status,
        beforeOrderStatus: item.lab_order?.status || null,
        order: refreshedOrder,
        progress};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'REJECT_ORDER_ITEM',
      entity: 'lab_order_item',
      entity_id: orderItemId,
      diff: {
        metadata: {
          reason,
          notes: payload.notes || null,
          before_item_status: mutation.beforeItemStatus,
          before_order_status: mutation.beforeOrderStatus,
          after_order_status: mutation.order?.status || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'REJECT_ORDER_ITEM',
      resourceType: 'order-item',
      resourceId: identifier}).catch(() => {});
    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'LAB_ORDER_ITEM_REJECTED'});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const reopenLabOrderItemResult = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const reason = String(payload?.reason || '').trim();
    if (!reason) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'reason' }]);
    }

    const orderItemId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order_item',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order_item.not_found'});

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const item = await labWorkspaceRepository.txFindOrderItemById(tx, orderItemId, {
        lab_order: { select: { id: true, status: true } }});
      if (!item) {
        throw new HttpError('errors.lab_order_item.not_found', 404);
      }

      const result = await labWorkspaceRepository.txFindFirstResult(
        tx,
        { lab_order_item_id: item.id },
        { created_at: 'desc' }
      );
      if (!result) {
        throw new HttpError('errors.lab_result.not_found', 404);
      }

      assertTransition(normalizeStatus(item.status) === 'COMPLETED', {
        from: item.status,
        to: 'IN_PROCESS'});
      assertTransition(
        RESULT_REOPENABLE_STATES.has(normalizeStatus(result.status)),
        {
          from: result.status,
          to: 'PENDING'}
      );

      await labWorkspaceRepository.txUpdateResult(tx, result.id, {
        status: 'PENDING',
        result_flag: null,
        reported_at: null});
      await labWorkspaceRepository.txUpdateOrderItem(tx, item.id, {
        status: 'IN_PROCESS'});

      const progress = await syncLabOrderProgress(tx, item.lab_order_id);
      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        item.lab_order_id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeItemStatus: item.status,
        beforeOrderStatus: item.lab_order?.status || null,
        order: refreshedOrder,
        progress,
        reopenedResultId: result.id};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'REOPEN_RESULT',
      entity: 'lab_order_item',
      entity_id: orderItemId,
      diff: {
        metadata: {
          reason,
          notes: payload.notes || null,
          before_item_status: mutation.beforeItemStatus,
          before_order_status: mutation.beforeOrderStatus,
          after_order_status: mutation.order?.status || null,
          reopened_result_id: mutation.reopenedResultId}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'REOPEN_RESULT',
      resourceType: 'order-item',
      resourceId: identifier}).catch(() => {});
    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'LAB_RESULT_REOPENED'});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};


const reverseLabOrderWorkflow = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const reason = String(payload?.reason || '').trim();
    if (!reason) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'reason' }]);
    }

    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order.not_found'});

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const order = await labWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.lab_order.not_found', 404);
      }

      const reverseTarget = resolveLatestReverseWorkflowTarget(order);
      assertTransition(Boolean(reverseTarget), {
        from: order.status,
        to: 'REVERSED'});

      if (reverseTarget.kind === 'RELEASE') {
        const item = await labWorkspaceRepository.txFindOrderItemById(
          tx,
          reverseTarget.orderItemId
        );
        const result = await labWorkspaceRepository.txFindResultById(
          tx,
          reverseTarget.resultId
        );
        if (!item || !result) {
          throw new HttpError('errors.lab_order_item.not_found', 404);
        }

        assertTransition(normalizeStatus(item.status) === 'COMPLETED', {
          from: item.status,
          to: 'IN_PROCESS'});
        assertTransition(
          RESULT_REOPENABLE_STATES.has(normalizeStatus(result.status)),
          {
            from: result.status,
            to: 'PENDING'}
        );

        await labWorkspaceRepository.txUpdateResult(tx, result.id, {
          status: 'PENDING',
          result_flag: null,
          reported_at: null});
        await labWorkspaceRepository.txUpdateOrderItem(tx, item.id, {
          status: 'IN_PROCESS'});
      } else {
        const sample = await labWorkspaceRepository.txFindSampleById(
          tx,
          reverseTarget.sampleId
        );
        if (!sample) {
          throw new HttpError('errors.lab_sample.not_found', 404);
        }

        if (reverseTarget.kind === 'RECEIVE') {
          assertTransition(normalizeStatus(sample.status) === 'RECEIVED', {
            from: sample.status,
            to: 'COLLECTED'});

          await labWorkspaceRepository.txUpdateSample(tx, sample.id, {
            status: 'COLLECTED',
            received_at: null});
        } else if (reverseTarget.kind === 'REJECT') {
          const restoredStatus = resolveRejectedSampleRestoreStatus(sample);
          assertTransition(Boolean(restoredStatus), {
            from: sample.status,
            to: restoredStatus || 'PENDING'});

          await labWorkspaceRepository.txUpdateSample(tx, sample.id, {
            status: restoredStatus,
            ...(restoredStatus === 'PENDING'
              ? {
                  collected_at: null,
                  received_at: null}
              : restoredStatus === 'COLLECTED'
                ? { received_at: null }
                : {})});
        } else {
          assertTransition(normalizeStatus(sample.status) === 'COLLECTED', {
            from: sample.status,
            to: 'PENDING'});

          await labWorkspaceRepository.txUpdateSample(tx, sample.id, {
            status: 'PENDING',
            collected_at: null,
            received_at: null});
        }
      }

      const progress = await syncLabOrderProgress(tx, order.id);
      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeOrderStatus: order.status,
        order: refreshedOrder,
        reverseTarget,
        progress};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'REVERSE',
      entity: 'lab_order',
      entity_id: orderId,
      diff: {
        metadata: {
          before_order_status: mutation.beforeOrderStatus,
          after_order_status: mutation.order?.status || null,
          reversed_step: mutation.reverseTarget?.kind || null,
          reversed_sample_id: mutation.reverseTarget?.sampleId || null,
          reversed_order_item_id: mutation.reverseTarget?.orderItemId || null,
          reversed_result_id: mutation.reverseTarget?.resultId || null,
          reason}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'REVERSE',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});
    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'LAB_WORKFLOW_REVERSED'});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const restoreLabOrderItem = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderItemId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order_item',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order_item.not_found'});

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const item = await labWorkspaceRepository.txFindOrderItemById(tx, orderItemId, {
        lab_order: { select: { id: true, status: true } }});
      if (!item) {
        throw new HttpError('errors.lab_order_item.not_found', 404);
      }

      assertTransition(normalizeStatus(item.status) === 'CANCELLED', {
        from: item.status,
        to: 'ORDERED'});

      await labWorkspaceRepository.txUpdateOrderItem(tx, item.id, {
        status: 'ORDERED',
        rejection_reason: null,
        rejection_notes: null,
        rejected_at: null});

      const progress = await syncLabOrderProgress(tx, item.lab_order_id);
      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        item.lab_order_id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeItemStatus: item.status,
        beforeOrderStatus: item.lab_order?.status || null,
        order: refreshedOrder,
        progress};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'RESTORE_ORDER_ITEM',
      entity: 'lab_order_item',
      entity_id: orderItemId,
      diff: {
        metadata: {
          before_item_status: mutation.beforeItemStatus,
          before_order_status: mutation.beforeOrderStatus,
          after_order_status: mutation.order?.status || null,
          reason: payload.reason || null,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'RESTORE_ORDER_ITEM',
      resourceType: 'order-item',
      resourceId: identifier}).catch(() => {});
    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'LAB_ORDER_ITEM_RESTORED'});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabOrderItems = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'lab_order',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order.not_found'});

    const panelId = String(payload?.panel_id || '').trim();
    const requestedItemIds = Array.isArray(payload?.order_item_ids)
      ? payload.order_item_ids
      : [];

    if (!panelId && requestedItemIds.length === 0) {
      throw new HttpError('errors.validation.field.required', 400, [
        { field: 'order_item_ids' }]);
    }

    const mutation = await labWorkspaceRepository.withTransaction(async (tx) => {
      const order = await labWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.lab_order.not_found', 404);
      }

      let targetIds = [];
      if (panelId) {
        const panelItems = await labWorkspaceRepository.txFindManyOrderItems(
          tx,
          { lab_order_id: order.id, panel_id: panelId },
          { id: true }
        );
        targetIds = panelItems.map((row) => row.id);
      } else {
        for (const rawId of requestedItemIds) {
          const itemId = await resolveModelIdOrThrow({
            identifier: rawId,
            model: 'lab_order_item',
            where: { deleted_at: null, lab_order_id: order.id },
            errorKey: 'errors.lab_order_item.not_found'});
          targetIds.push(itemId);
        }
        targetIds = [...new Set(targetIds)];
      }

      if (!targetIds.length) {
        throw new HttpError('errors.lab_order_item.not_found', 404);
      }

      const totalActiveItems = await labWorkspaceRepository.txCountOrderItems(tx, {
        lab_order_id: order.id});
      if (targetIds.length >= totalActiveItems) {
        throw new HttpError('errors.lab_order.at_least_one_active_test_required', 409, [
          { field: 'order_item_ids' }]);
      }

      const deletedAt = new Date();
      await labWorkspaceRepository.txUpdateResultsMany(
        tx,
        { lab_order_item_id: { in: targetIds } },
        { deleted_at: deletedAt }
      );
      await labWorkspaceRepository.txUpdateOrderItemsMany(
        tx,
        { id: { in: targetIds } },
        { deleted_at: deletedAt }
      );

      const progress = await syncLabOrderProgress(tx, order.id);
      const refreshedOrder = await labWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        LAB_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeOrderStatus: order.status,
        order: refreshedOrder,
        deletedItemIds: targetIds,
        panelId: panelId || null,
        progress};
    });

    createAuditLog({
      tenant_id: resolveAuditTenantId(mutation.order),
      user_id: userId,
      action: 'DELETE_ORDER_ITEMS',
      entity: 'lab_order',
      entity_id: orderId,
      diff: {
        metadata: {
          before_order_status: mutation.beforeOrderStatus,
          after_order_status: mutation.order?.status || null,
          panel_id: mutation.panelId,
          deleted_item_count: mutation.deletedItemIds.length,
          reason: payload.reason || null,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapLabOrderWorkflowRecord(mutation.order);
    publishLabRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'DELETE_ORDER_ITEMS',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});
    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'LAB_ORDER_ITEMS_DELETED'});

    return {
      workflow,
      deleted_item_count: mutation.deletedItemIds.length};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const resolveLegacyRouteIdentifier = async (resource, identifier) => {
  try {
    const normalizedResource = String(resource || '').trim().toLowerCase();
    const normalizedIdentifier = normalizeIdentifier(identifier);
    if (!normalizedIdentifier) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    const config = LEGACY_ROUTE_CONFIG[normalizedResource];
    if (!config) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    const record = await resolveModelRecordOrThrow({
      identifier: normalizedIdentifier,
      model: config.model,
      where: { deleted_at: null },
      select: {
        id: true,
        human_friendly_id: true},
      errorKey: 'errors.resource.not_found'});

    const publicIdentifier = toPublicIdentifier(
      record?.human_friendly_id,
      normalizedIdentifier
    );
    const safeIdentifier =
      publicIdentifier ||
      (isUuidLike(normalizedIdentifier)
        ? null
        : String(normalizedIdentifier).trim().toUpperCase());

    if (!safeIdentifier) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    return {
      id: safeIdentifier,
      resource: config.resource,
      identifier: safeIdentifier,
      route: `${config.route}/${encodeURIComponent(safeIdentifier)}`,
      matched_by: isUuidLike(normalizedIdentifier)
        ? 'uuid'
        : 'human_friendly_id'};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  searchLabOrderContextPatients,
  getLabOrderPatientContext,
  getLabWorkbench,
  getLabOrderWorkflow,
  collectLabOrder,
  receiveLabSample,
  rejectLabSample,
  releaseLabOrderItem,
  verifyLabOrderResults,
  rejectLabOrderItem,
  reopenLabOrderItemResult,
  reverseLabOrderWorkflow,
  restoreLabOrderItem,
  deleteLabOrderItems,
  resolveLegacyRouteIdentifier};
