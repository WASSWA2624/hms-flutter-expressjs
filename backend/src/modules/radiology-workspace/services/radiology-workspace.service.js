const crypto = require('crypto');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { normalizeIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const prisma = require('@prisma/client');
const radiologyWorkspaceRepository = require('@repositories/radiology-workspace/radiology-workspace.repository');
const radiologyOrderService = require('@services/radiology-order/radiology-order.service');
const { emitToUsers, DIAGNOSTIC_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');
const { STORAGE_PROVIDER, RADIOLOGY_ATTESTATION_V2 } = require('@config/env');
const dicomWebClient = require('@lib/dicomweb/client');
const {
  reverseClinicalRequestBilling,
  extractStoredClinicalBilling} = require('@lib/billing/clinical-request-billing');
const {
  RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE,
  RADIOLOGY_STUDY_WITH_RELATIONS_INCLUDE,
  RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  toDateOrNull,
  applyDateRangeFilter} = require('@services/radiology-workspace/radiology.shared');
const {
  toPublicIdentifier,
  mapRadiologyOrderRecord,
  mapRadiologyOrderWorkflowRecord,
  mapRadiologyResultRecord,
  mapImagingStudyRecord,
  mapPacsLinkRecord} = require('@services/radiology-workspace/radiology.serializer');

const ORDER_COMPLETION_STATES = new Set(['COMPLETED', 'CANCELLED']);
const DEFAULT_REFERENCE_LIMIT = 20;
const MAX_REFERENCE_LIMIT = 50;
const RADIOLOGY_RECIPIENT_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
  ROLES.RADIOLOGY_TECH,
  ROLES.RADIOLOGIST,
  ROLES.MEDICAL_RECORDS_CLERK];

const resolveEquipmentRegistryId = async (identifier) => {
  if (!identifier) return null;
  return resolveModelIdOrThrow({
    identifier,
    model: 'equipment_registry',
    where: { deleted_at: null },
    errorKey: 'errors.equipment_registry.not_found'});
};

const resolveAssigneeUserId = async (identifier) => {
  if (!identifier) return null;
  return resolveModelIdOrThrow({
    identifier,
    model: 'user',
    where: { deleted_at: null },
    errorKey: 'errors.user.not_found'});
};

const PATIENT_WORKBENCH_SCAN_LIMIT = 5000;
const WORKBENCH_VIEWS = new Set(['PATIENTS', 'ORDERS']);

const normalizeWorkbenchView = (value) => {
  const normalized = String(value || 'PATIENTS').trim().toUpperCase();
  return WORKBENCH_VIEWS.has(normalized) ? normalized : 'PATIENTS';
};

const normalizeRadiologyStatus = (value) => String(value || '').trim().toUpperCase();

const normalizeWorkspaceOrderRequest = (request = {}, fallback = {}) => {
  const details = {
    ...(fallback.request_details && typeof fallback.request_details === 'object'
      ? fallback.request_details
      : {}),
    ...(request.request_details && typeof request.request_details === 'object'
      ? request.request_details
      : {})};
  return {
    ...request,
    clinical_note: request.clinical_note || fallback.clinical_note || fallback.notes || null,
    request_details: details};
};

const normalizeWorkspaceCreateOrderPayload = (payload = {}) => {
  const requestedTests = Array.isArray(payload.requested_tests)
    ? payload.requested_tests
    : [];
  if (requestedTests.length > 0) {
    return {
      ...payload,
      requested_tests: requestedTests.map((request) =>
        normalizeWorkspaceOrderRequest(request, payload)
      )};
  }

  const legacyRadiologyTestId = String(payload.radiology_procedure_id || payload.radiology_test_id || '').trim();
  return {
    ...payload,
    requested_tests: legacyRadiologyTestId
      ? [
          normalizeWorkspaceOrderRequest(
            { radiology_procedure_id: legacyRadiologyTestId },
            payload
          )]
      : []};
};

const publicOrderIdentifierFromCreateResult = (result = {}) => {
  const firstCreated = Array.isArray(result.created_orders)
    ? result.created_orders[0]
    : null;
  return (
    result.display_id ||
    result.id ||
    firstCreated?.display_id ||
    firstCreated?.id ||
    null
  );
};

const radiologyPatientGroupKey = (order) =>
  String(order?.patient_id || order?.patient?.id || order?.id || '').trim();

const groupRadiologyOrdersByPatient = (records = []) => {
  const groups = new Map();
  records.forEach((record) => {
    const key = radiologyPatientGroupKey(record);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(record);
  });
  return Array.from(groups.values());
};

const uniqueRadiologyByKey = (items, keySelector) => {
  const seen = new Set();
  return (items || []).filter((item) => {
    const key = keySelector(item);
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

const radiologyOrderIsTerminal = (order) => ORDER_COMPLETION_STATES.has(normalizeRadiologyStatus(order?.status));

const mapRadiologyPatientWorkItem = (records = []) => {
  const mapped = records.map((record) => mapRadiologyOrderRecord(record)).filter(Boolean);
  if (!mapped.length) return null;
  const representative = mapped[0];
  const requestedTests = uniqueRadiologyByKey(
    mapped.flatMap((order) => order.requested_tests || []),
    (item) => item.radiology_test_id || item.test_display_name || item.modality
  );
  const results = uniqueRadiologyByKey(mapped.flatMap((order) => order.results || []), (item) => item.id);
  const studies = uniqueRadiologyByKey(mapped.flatMap((order) => order.imaging_studies || []), (item) => item.id);
  const statuses = mapped.map((order) => normalizeRadiologyStatus(order.status)).filter(Boolean);
  const hasDraft = results.some((result) => normalizeRadiologyStatus(result?.status) === 'DRAFT');
  const hasReleased = results.some((result) => ['FINAL', 'AMENDED'].includes(normalizeRadiologyStatus(result?.status)));
  const activeOrders = mapped.filter((order) => !radiologyOrderIsTerminal(order));
  const status = hasDraft
    ? 'REPORTING'
    : statuses.includes('IN_PROCESS')
      ? 'IN_PROCESS'
      : statuses.includes('ORDERED')
        ? 'ORDERED'
        : (statuses.length && statuses.every((entry) => entry === 'COMPLETED')) || hasReleased
          ? 'COMPLETED'
          : statuses.length && statuses.every((entry) => entry === 'CANCELLED')
            ? 'CANCELLED'
            : representative.status;

  const testNames = requestedTests
    .map((item) => item.test_display_name || item.radiology_test_display_name || item.modality)
    .filter(Boolean);
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
    requested_tests: requestedTests,
    test_display_name: testsSummary || representative.test_display_name,
    radiology_test_display_name: testsSummary || representative.radiology_test_display_name,
    study_count: studies.length,
    result_count: results.length,
    draft_result_count: results.filter((entry) => normalizeRadiologyStatus(entry?.status) === 'DRAFT').length,
    final_result_count: results.filter((entry) => normalizeRadiologyStatus(entry?.status) === 'FINAL').length,
    amended_result_count: results.filter((entry) => normalizeRadiologyStatus(entry?.status) === 'AMENDED').length,
    unsynced_study_count: studies.filter((entry) => Number(entry?.pacs_link_count || 0) === 0).length,
    tests_summary: testsSummary,
    results,
    imaging_studies: studies};
};

const summarizeRadiologyPatientGroups = (groups = []) => {
  const patientItems = groups.map(mapRadiologyPatientWorkItem).filter(Boolean);
  const hasStatus = (item, values) => values.has(normalizeRadiologyStatus(item.status));
  return {
    total_patients: patientItems.length,
    actionable_patients: patientItems.filter((item) => !hasStatus(item, new Set(['COMPLETED', 'CANCELLED']))).length,
    ordered_patients: patientItems.filter((item) => hasStatus(item, new Set(['ORDERED']))).length,
    processing_patients: patientItems.filter((item) => hasStatus(item, new Set(['IN_PROCESS']))).length,
    reporting_patients: patientItems.filter((item) => hasStatus(item, new Set(['REPORTING'])) || Number(item.draft_result_count || 0) > 0).length,
    released_patients: patientItems.filter((item) => Number(item.final_result_count || 0) + Number(item.amended_result_count || 0) > 0).length,
    completed_patients: patientItems.filter((item) => hasStatus(item, new Set(['COMPLETED']))).length,
    cancelled_patients: patientItems.filter((item) => hasStatus(item, new Set(['CANCELLED']))).length};
};

const LEGACY_ROUTE_CONFIG = Object.freeze({
  'radiology-orders': {
    model: 'radiology_order',
    resource: 'orders',
    route: '/radiology/orders'},
  'radiology-results': {
    model: 'radiology_result',
    resource: 'results',
    route: '/radiology/results'},
  'radiology-tests': {
    model: 'radiology_procedure',
    resource: 'tests',
    route: '/radiology/tests'},
  'imaging-studies': {
    model: 'imaging_study',
    resource: 'studies',
    route: '/radiology/studies'},
  'imaging-assets': {
    model: 'imaging_asset',
    resource: 'assets',
    route: '/radiology/assets'},
  'pacs-links': {
    model: 'pacs_link',
    resource: 'pacs-links',
    route: '/radiology/pacs-links'}});

const appendAnd = (where, clause) => {
  if (!clause || typeof clause !== 'object') return;
  if (!Array.isArray(where.AND)) where.AND = [];
  where.AND.push(clause);
};

const normalizeEnumFilter = (value, fallback) => {
  const normalized = String(value || '').trim().toUpperCase();
  if (!normalized) return fallback;
  return normalized;
};

const assertTransition = (condition, details = {}) => {
  if (condition) return;
  throw new HttpError('errors.radiology_workflow.invalid_transition', 400, [details]);
};

const sanitizeForPath = (value) =>
  String(value || '')
    .trim()
    .replace(/[^A-Za-z0-9._-]+/g, '_')
    .slice(0, 120);

const buildUploadStorageKey = (studyId, fileName) => {
  const safeName = sanitizeForPath(fileName || 'asset.bin') || 'asset.bin';
  const timestamp = new Date().toISOString().replace(/[:.]/g, '');
  return `radiology/${sanitizeForPath(studyId)}/${timestamp}-${safeName}`;
};

const composeReportText = ({ reportText, findings, impression }) => {
  const normalizedReport = String(reportText || '').trim();
  if (normalizedReport) return normalizedReport;

  const parts = [];
  const normalizedFindings = String(findings || '').trim();
  const normalizedImpression = String(impression || '').trim();
  if (normalizedFindings) parts.push(`Findings:\n${normalizedFindings}`);
  if (normalizedImpression) parts.push(`Impression:\n${normalizedImpression}`);
  return parts.join('\n\n').trim() || null;
};

const composeAddendumText = (existingText, addendumText) => {
  const base = String(existingText || '').trim();
  const addendum = String(addendumText || '').trim();
  if (!addendum) return base || null;
  if (!base) return `Addendum:\n${addendum}`;
  return `${base}\n\nAddendum:\n${addendum}`;
};

const createResultAttestation = async ({
  tx,
  resultId,
  phase,
  userId,
  userRole,
  statement = null,
  reason = null,
  ipAddress = null,
  attestedAt = null}) =>
  radiologyWorkspaceRepository.txCreateResultAttestation(tx, {
    radiology_result_id: resultId,
    phase,
    attested_by_user_id: userId,
    attested_role: userRole || null,
    statement: statement || null,
    reason: reason || null,
    ip_address: ipAddress || null,
    attested_at: toDateOrNull(attestedAt, new Date())});

const normalizeText = (value) => String(value || '').trim();

const normalizeReferenceLimit = (value) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return DEFAULT_REFERENCE_LIMIT;
  return Math.min(MAX_REFERENCE_LIMIT, Math.max(1, Math.floor(parsed)));
};

const toPersonDisplayName = (...parts) => parts.map(normalizeText).filter(Boolean).join(' ').trim();

const buildScopedWhere = (scope = {}) => ({
  ...(scope.tenantId ? { tenant_id: scope.tenantId } : {}),
  ...(scope.facilityId ? { facility_id: scope.facilityId } : {})});

const mapPatientReferenceOption = (record) => {
  const value = toPublicIdentifier(record?.human_friendly_id, record?.id);
  if (!value) return null;
  const name = toPersonDisplayName(record?.first_name, record?.last_name);
  const contact = normalizeText(record?.contacts?.[0]?.value) || null;
  return {
    value,
    label: name || value,
    subtitle: [value, contact].filter(Boolean).join(' | ') || null};
};

const mapEncounterReferenceOption = (record) => {
  const value = toPublicIdentifier(record?.human_friendly_id, record?.id);
  if (!value) return null;

  const patientName = toPersonDisplayName(
    record?.patient?.first_name,
    record?.patient?.last_name
  );
  const patientId = toPublicIdentifier(record?.patient?.human_friendly_id, record?.patient?.id);
  const startedAt = record?.started_at ? new Date(record.started_at).toISOString() : null;

  return {
    value,
    label: patientName ? `${value} | ${patientName}` : value,
    subtitle: [patientId, normalizeText(record?.status), startedAt].filter(Boolean).join(' | ') || null,
    patient_id: patientId};
};

const mapTestReferenceOption = (record) => {
  const value = toPublicIdentifier(record?.human_friendly_id, record?.id);
  if (!value) return null;
  const name = normalizeText(record?.name);
  const code = normalizeText(record?.code);
  const modality = normalizeText(record?.modality).toUpperCase() || null;
  return {
    value,
    label: name || code || value,
    subtitle: [value, code, modality].filter(Boolean).join(' | ') || null};
};

const mapUserReferenceOption = (record) => {
  const value = toPublicIdentifier(record?.human_friendly_id, record?.id);
  if (!value) return null;
  const name = toPersonDisplayName(
    record?.profile?.first_name,
    record?.profile?.middle_name,
    record?.profile?.last_name
  );
  const email = normalizeText(record?.email);
  return {
    value,
    label: name || email || value,
    subtitle: [value, email].filter(Boolean).join(' | ') || null};
};

const buildWorkbenchOrderWhere = async (filters = {}, options = {}) => {
  const includeSearch = options.includeSearch !== false;
  const where = {};

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

  if (filters.modality) {
    appendAnd(where, {
      OR: [
        { radiology_procedure: { modality: filters.modality } },
        { imaging_studies: { some: { deleted_at: null, modality: filters.modality } } }]});
  }

  if (filters.priority) {
    appendAnd(where, {
      request_details: {
        path: ['priority'],
        equals: filters.priority}});
  }

  const billingGate = normalizeEnumFilter(filters.billing_gate, null);
  if (billingGate === 'CONFIRMED') {
    appendAnd(where, {
      OR: [
        {
          request_details: {
            path: ['billing', 'payment_status'],
            not: null}},
        {
          request_details: {
            path: ['billing', 'authorization_status'],
            not: null}}]});
  } else if (billingGate === 'AWAITING') {
    appendAnd(where, {
      AND: [
        {
          NOT: {
            request_details: {
              path: ['billing', 'payment_status'],
              not: null}}},
        {
          NOT: {
            request_details: {
              path: ['billing', 'authorization_status'],
              not: null}}}]});
  }

  applyDateRangeFilter(where, 'ordered_at', filters.from, filters.to);

  const stage = normalizeEnumFilter(filters.stage, 'ALL');
  if (stage === 'ORDERED') {
    appendAnd(where, { status: 'ORDERED' });
  } else if (stage === 'PROCESSING') {
    appendAnd(where, { status: 'IN_PROCESS' });
  } else if (stage === 'REPORTING') {
    appendAnd(where, {
      status: { in: ['IN_PROCESS', 'COMPLETED'] },
      OR: [
        { results: { some: { deleted_at: null, status: 'DRAFT' } } },
        { results: { none: { deleted_at: null, status: 'FINAL' } } }]});
  } else if (stage === 'COMPLETED') {
    appendAnd(where, { status: 'COMPLETED' });
  } else if (stage === 'CANCELLED') {
    appendAnd(where, { status: 'CANCELLED' });
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
        { radiology_procedure: { human_friendly_id: { contains: searchTerm.upper } } },
        { radiology_procedure: { name: { contains: searchTerm.raw } } },
        { radiology_procedure: { code: { contains: searchTerm.raw } } },
        { results: { some: { human_friendly_id: { contains: searchTerm.upper } } } },
        { imaging_studies: { some: { human_friendly_id: { contains: searchTerm.upper } } } },
        { imaging_studies: { some: { assets: { some: { file_name: { contains: searchTerm.raw } } } } } }]});
  }

  return where;
};

const resolveRoleRecipients = async ({ tenantId, facilityId = null }) => {
  if (!tenantId || !prisma?.user_role?.findMany) return [];

  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      role: {
        name: { in: RADIOLOGY_RECIPIENT_ROLES },
        deleted_at: null},
      ...(facilityId ? { OR: [{ facility_id: null }, { facility_id: facilityId }] } : {})},
    select: {
      user_id: true}});

  return rows.map((item) => item.user_id).filter(Boolean);
};

const buildRadiologyRealtimePayload = ({
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
    target_path: orderId ? `/radiology?id=${encodeURIComponent(orderId)}` : '/radiology',
    workflow};
};

const publishRadiologyRealtimeUpdates = async ({
  workflow,
  orderRecord,
  actorUserId = null,
  action,
  resourceType = null,
  resourceId = null,
  resultRecord = null}) => {
  try {
    const tenantId = orderRecord?.patient?.tenant_id || null;
    if (!tenantId) return;

    const facilityId = orderRecord?.patient?.facility_id || null;
    const recipientUserIds = await resolveRoleRecipients({ tenantId, facilityId });
    const recipients = recipientUserIds.filter((userId) => userId && userId !== actorUserId);
    if (!recipients.length) return;

    const workflowPayload = buildRadiologyRealtimePayload({
      workflow,
      action,
      resourceType,
      resourceId});

    emitToUsers(
      recipients,
      DIAGNOSTIC_EVENTS.RADIOLOGY_WORKFLOW_UPDATED,
      workflowPayload
    );

    if (!resultRecord) return;

    const resultStatus = String(resultRecord.status || '').trim().toUpperCase() || null;
    const resultPayload = {
      order_id: workflowPayload.order_id,
      order_public_id: workflowPayload.order_public_id,
      patient_id: workflowPayload.patient_id,
      patient_public_id: workflowPayload.patient_public_id,
      result_id: resultRecord.id || null,
      result_public_id: resultRecord.id || null,
      result_status: resultStatus,
      finalization_requested: Boolean(resultRecord.finalization?.requested),
      finalization_attested: Boolean(resultRecord.finalization?.attested),
      finalization_pending_attestation: Boolean(resultRecord.finalization?.pending_attestation),
      action: workflowPayload.action,
      occurred_at: workflowPayload.occurred_at,
      target_path: resultRecord.id
        ? `/radiology/results/${encodeURIComponent(resultRecord.id)}`
        : workflowPayload.target_path};

    emitToUsers(
      recipients,
      DIAGNOSTIC_EVENTS.RADIOLOGY_RESULT_UPDATED,
      resultPayload
    );

    if (['FINAL', 'AMENDED'].includes(resultStatus || '')) {
      emitToUsers(
        recipients,
        DIAGNOSTIC_EVENTS.RADIOLOGY_RESULT_READY,
        resultPayload
      );
    }
  } catch (_error) {
    // realtime events must never block workflow updates
  }
};

/**
 * Hand off to the OPD orchestrator after a radiology workflow mutation so the
 * encounter can advance out of `RADIOLOGY_REQUESTED` / `LAB_AND_RADIOLOGY_REQUESTED`
 * once imaging work is done. Radiology never mutates OPD stages itself — it only
 * signals completion. The call is fire-and-forget, forward-only, and a safe no-op
 * for IPD orders (no OPD flow resolves on the encounter).
 */
const syncOpdFlowForOrder = (
  orderRecord,
  { userId = null, trigger = 'RADIOLOGY_WORKFLOW_UPDATED' } = {}
) => {
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
    // OPD orchestration must never block radiology workflow updates.
  }
};

const getRadiologyWorkbench = async (filters, page, limit, sortBy, order) => {
  try {
    const view = normalizeWorkbenchView(filters?.view);
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { ordered_at: 'desc' };

    const [where, summaryWhere] = await Promise.all([
      buildWorkbenchOrderWhere(filters, { includeSearch: true }),
      buildWorkbenchOrderWhere(filters, { includeSearch: false })]);

    const [
      orderWorklistRecords,
      total,
      totalOrders,
      orderedQueue,
      processingQueue,
      completedOrders,
      cancelledOrders,
      draftReports,
      finalizedReports,
      amendedReports,
      studiesTotal,
      unsyncedStudies,
      summaryOrderRecords] = await Promise.all([
      view === 'PATIENTS'
        ? radiologyWorkspaceRepository.findManyOrders(
            where,
            0,
            PATIENT_WORKBENCH_SCAN_LIMIT,
            orderBy,
            RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
          )
        : radiologyWorkspaceRepository.findManyOrders(
            where,
            skip,
            limit,
            orderBy,
            RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
          ),
      view === 'PATIENTS'
        ? Promise.resolve(0)
        : radiologyWorkspaceRepository.countOrders(where),
      radiologyWorkspaceRepository.countOrders(summaryWhere),
      radiologyWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'ORDERED'}),
      radiologyWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'IN_PROCESS'}),
      radiologyWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'COMPLETED'}),
      radiologyWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'CANCELLED'}),
      radiologyWorkspaceRepository.countResults({
        status: 'DRAFT',
        radiology_order: {
          deleted_at: null,
          ...summaryWhere}}),
      radiologyWorkspaceRepository.countResults({
        status: 'FINAL',
        radiology_order: {
          deleted_at: null,
          ...summaryWhere}}),
      radiologyWorkspaceRepository.countResults({
        status: 'AMENDED',
        radiology_order: {
          deleted_at: null,
          ...summaryWhere}}),
      radiologyWorkspaceRepository.countStudies({
        radiology_order: {
          deleted_at: null,
          ...summaryWhere}}),
      radiologyWorkspaceRepository.countStudies({
        radiology_order: {
          deleted_at: null,
          ...summaryWhere},
        pacs_links: {
          none: {
            deleted_at: null}}}),
      radiologyWorkspaceRepository.findManyOrders(
        summaryWhere,
        0,
        PATIENT_WORKBENCH_SCAN_LIMIT,
        orderBy,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      )]);

    const patientGroups = groupRadiologyOrdersByPatient(orderWorklistRecords);
    const patientSummary = summarizeRadiologyPatientGroups(
      groupRadiologyOrdersByPatient(summaryOrderRecords)
    );
    const patientWorklist = patientGroups.map(mapRadiologyPatientWorkItem).filter(Boolean);
    const pagedPatientWorklist = patientWorklist.slice(skip, skip + limit);
    const worklist = view === 'PATIENTS'
      ? pagedPatientWorklist
      : orderWorklistRecords.map((record) => mapRadiologyOrderRecord(record)).filter(Boolean);
    const worklistTotal = view === 'PATIENTS' ? patientWorklist.length : total;

    return {
      summary: {
        view: view.toLowerCase(),
        total_orders: totalOrders,
        ordered_queue: orderedQueue,
        processing_queue: processingQueue,
        draft_reports: draftReports,
        finalized_reports: finalizedReports,
        amended_reports: amendedReports,
        completed_orders: completedOrders,
        cancelled_orders: cancelledOrders,
        studies_total: studiesTotal,
        unsynced_studies: unsyncedStudies,
        ...patientSummary},
      worklist,
      pagination: buildPagination(page, limit, worklistTotal)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getRadiologyReferenceData = async (filters = {}, actorScope = {}) => {
  try {
    const limit = normalizeReferenceLimit(filters.limit);
    const searchTerm = normalizeSearchTerm(filters.search);
    const patientFilterId = await resolveModelIdOrThrow({
      identifier: filters.patient_id,
      model: 'patient',
      where: { deleted_at: null },
      errorKey: 'errors.patient.not_found',
      allowNull: true});
    const scope = {
      tenantId: normalizeIdentifier(actorScope.tenant_id) || null,
      facilityId: normalizeIdentifier(actorScope.facility_id) || null};

    const patientWhere = {
      ...buildScopedWhere(scope),
      ...(searchTerm
        ? {
            OR: [
              { human_friendly_id: { contains: searchTerm.upper } },
              { first_name: { contains: searchTerm.raw } },
              { last_name: { contains: searchTerm.raw } },
              { contacts: { some: { deleted_at: null, value: { contains: searchTerm.raw } } } }]}
        : {})};

    const encounterWhere = {
      ...(scope.tenantId ? { tenant_id: scope.tenantId } : {}),
      ...(scope.facilityId ? { facility_id: scope.facilityId } : {}),
      ...(patientFilterId ? { patient_id: patientFilterId } : {}),
      ...(searchTerm
        ? {
            OR: [
              { human_friendly_id: { contains: searchTerm.upper } },
              { patient: { human_friendly_id: { contains: searchTerm.upper } } },
              { patient: { first_name: { contains: searchTerm.raw } } },
              { patient: { last_name: { contains: searchTerm.raw } } }]}
        : {})};

    const testWhere = {
      ...(scope.tenantId ? { tenant_id: scope.tenantId } : {}),
      ...(searchTerm
        ? {
            OR: [
              { human_friendly_id: { contains: searchTerm.upper } },
              { name: { contains: searchTerm.raw } },
              { code: { contains: searchTerm.raw } },
              { modality: searchTerm.upper }]}
        : {})};

    const userWhere = {
      ...buildScopedWhere(scope),
      ...(searchTerm
        ? {
            OR: [
              { human_friendly_id: { contains: searchTerm.upper } },
              { email: { contains: searchTerm.raw } },
              { profile: { first_name: { contains: searchTerm.raw } } },
              { profile: { middle_name: { contains: searchTerm.raw } } },
              { profile: { last_name: { contains: searchTerm.raw } } }]}
        : {})};

    const [patients, encounters, tests, users] = await Promise.all([
      radiologyWorkspaceRepository.findReferencePatients({
        where: patientWhere,
        take: limit}),
      radiologyWorkspaceRepository.findReferenceEncounters({
        where: encounterWhere,
        take: limit}),
      radiologyWorkspaceRepository.findReferenceRadiologyTests({
        where: testWhere,
        take: limit}),
      radiologyWorkspaceRepository.findReferenceUsers({
        where: userWhere,
        take: limit})]);

    return {
      patients: patients.map(mapPatientReferenceOption).filter(Boolean),
      encounters: encounters.map(mapEncounterReferenceOption).filter(Boolean),
      radiology_tests: tests.map(mapTestReferenceOption).filter(Boolean),
      assignees: users.map(mapUserReferenceOption).filter(Boolean)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createRadiologyOrder = async (payload = {}, userId, ipAddress) => {
  try {
    const normalizedPayload = normalizeWorkspaceCreateOrderPayload(payload);

    const created = await radiologyOrderService.createRadiologyOrder(
      normalizedPayload,
      userId,
      ipAddress
    );
    const publicIdentifier = publicOrderIdentifierFromCreateResult(created);
    const orderId = await resolveModelIdOrThrow({
      identifier: publicIdentifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const orderRecord = await radiologyWorkspaceRepository.findOrderById(
      orderId,
      RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
    );
    if (!orderRecord) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }

    const workflow = mapRadiologyOrderWorkflowRecord(orderRecord);

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord,
      actorUserId: userId || null,
      action: 'CREATE_ORDER',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});

    return {
      workflow,
      order: mapRadiologyOrderRecord(orderRecord),
      created_orders: Array.isArray(created.created_orders)
        ? created.created_orders
        : undefined};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getRadiologyOrderWorkflow = async (identifier) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const orderRecord = await radiologyWorkspaceRepository.findOrderById(
      orderId,
      RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
    );
    if (!orderRecord) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }

    return mapRadiologyOrderWorkflowRecord(orderRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};


const updateRadiologyOrderRequestDetails = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      const currentDetails =
        order.request_details &&
        typeof order.request_details === 'object' &&
        !Array.isArray(order.request_details)
          ? order.request_details
          : {};
      const incomingDetails =
        payload.request_details &&
        typeof payload.request_details === 'object' &&
        !Array.isArray(payload.request_details)
          ? payload.request_details
          : {};
      const nextDetails = {
        ...currentDetails,
        ...incomingDetails};
      const data = {
        request_details: nextDetails};
      if (Object.prototype.hasOwnProperty.call(payload, 'clinical_note')) {
        data.clinical_note = normalizeText(payload.clinical_note) || null;
      }

      await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, data);

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeOrder: order,
        order: refreshedOrder};
    });

    createAuditLog({
      user_id: userId,
      action: 'UPDATE_REQUEST_DETAILS',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        before: {
          clinical_note: mutation.beforeOrder?.clinical_note || null,
          request_details: mutation.beforeOrder?.request_details || {}},
        after: {
          clinical_note: mutation.order?.clinical_note || null,
          request_details: mutation.order?.request_details || {}}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'UPDATE_REQUEST_DETAILS',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});

    return {
      workflow,
      order: mapRadiologyOrderRecord(mutation.order)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const assignRadiologyOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const assigneeUserId = await resolveAssigneeUserId(
      payload.assignee_user_id || payload.assigned_user_id || null
    );
    const equipmentRegistryId = await resolveEquipmentRegistryId(
      payload.equipment_registry_id || null
    );

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      assertTransition(order.status !== 'CANCELLED', {
        from: order.status,
        to: 'ASSIGNED'});

      const updateData = {
        assigned_user_id: assigneeUserId,
        scheduled_at: toDateOrNull(payload.scheduled_at, null),
        room: payload.room == null ? order.room : String(payload.room || '').trim() || null,
        equipment_registry_id: equipmentRegistryId};

      // Preserve existing assignment fields when omitted from payload.
      if (!Object.prototype.hasOwnProperty.call(payload, 'assignee_user_id')
        && !Object.prototype.hasOwnProperty.call(payload, 'assigned_user_id')) {
        updateData.assigned_user_id = order.assigned_user_id || null;
      }
      if (!Object.prototype.hasOwnProperty.call(payload, 'scheduled_at')) {
        updateData.scheduled_at = order.scheduled_at || null;
      }
      if (!Object.prototype.hasOwnProperty.call(payload, 'room')) {
        updateData.room = order.room || null;
      }
      if (!Object.prototype.hasOwnProperty.call(payload, 'equipment_registry_id')) {
        updateData.equipment_registry_id = order.equipment_registry_id || null;
      }

      await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, updateData);

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        before: order,
        order: refreshedOrder};
    });

    createAuditLog({
      user_id: userId,
      action: 'ASSIGN',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        before: {
          assigned_user_id: mutation.before?.assigned_user_id || null,
          scheduled_at: mutation.before?.scheduled_at || null,
          room: mutation.before?.room || null,
          equipment_registry_id: mutation.before?.equipment_registry_id || null},
        after: {
          assigned_user_id: mutation.order?.assigned_user_id || null,
          scheduled_at: mutation.order?.scheduled_at || null,
          room: mutation.order?.room || null,
          equipment_registry_id: mutation.order?.equipment_registry_id || null},
        metadata: {
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'ASSIGN',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});

    return {
      workflow,
      assignment: {
        assignee_user_id: toPublicIdentifier(
          mutation.order?.assigned_user?.human_friendly_id,
          mutation.order?.assigned_user_id
        ),
        scheduled_at: workflow?.order?.scheduled_at || null,
        room: workflow?.order?.room || null,
        equipment_registry_id: workflow?.order?.equipment_registry_id || null}};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const startRadiologyOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      if (order.status === 'IN_PROCESS') {
        return {
          beforeStatus: order.status,
          order};
      }

      assertTransition(order.status === 'ORDERED', {
        from: order.status,
        to: 'IN_PROCESS'});

      await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
        status: 'IN_PROCESS'});

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder};
    });

    createAuditLog({
      user_id: userId,
      action: 'START',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        metadata: {
          before_status: mutation.beforeStatus,
          after_status: mutation.order?.status,
          started_at: payload.started_at || new Date().toISOString(),
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'START',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const completeRadiologyOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      if (order.status === 'COMPLETED') {
        return {
          beforeStatus: order.status,
          order};
      }

      assertTransition(order.status === 'IN_PROCESS', {
        from: order.status,
        to: 'COMPLETED'});

      const hasFinalResult = (order.results || []).some((entry) => entry.status === 'FINAL');
      assertTransition(hasFinalResult, {
        reason: 'FINAL_RESULT_REQUIRED'});

      await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
        status: 'COMPLETED'});

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder};
    });

    createAuditLog({
      user_id: userId,
      action: 'COMPLETE',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        metadata: {
          before_status: mutation.beforeStatus,
          after_status: mutation.order?.status,
          completed_at: payload.completed_at || new Date().toISOString(),
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'COMPLETE',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});

    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'RADIOLOGY_ORDER_COMPLETED'});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const cancelRadiologyOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      if (order.status === 'CANCELLED') {
        return {
          beforeStatus: order.status,
          order};
      }

      assertTransition(order.status !== 'COMPLETED', {
        from: order.status,
        to: 'CANCELLED'});

      await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
        status: 'CANCELLED'});

      const existingSnapshot = extractStoredClinicalBilling(order);
      if (existingSnapshot?.invoice_id) {
        await reverseClinicalRequestBilling(tx, { existingSnapshot });
        const currentDetails =
          order.request_details && typeof order.request_details === 'object'
            ? { ...order.request_details }
            : {};
        delete currentDetails.billing;
        await tx.radiology_order.update({
          where: { id: order.id },
          data: { request_details: currentDetails }});
      }

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder};
    });

    createAuditLog({
      user_id: userId,
      action: 'CANCEL',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        metadata: {
          reason: payload.reason || null,
          before_status: mutation.beforeStatus,
          after_status: mutation.order?.status,
          cancelled_at: payload.cancelled_at || new Date().toISOString(),
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'CANCEL',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null}).catch(() => {});

    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'RADIOLOGY_ORDER_CANCELLED'});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createRadiologyStudy = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      assertTransition(order.status !== 'CANCELLED', {
        from: order.status,
        to: 'CREATE_STUDY'});

      const modality =
        String(payload.modality || '').trim().toUpperCase() ||
        String((order?.radiology_procedure || order?.radiology_test)?.modality || '').trim().toUpperCase() ||
        'XRAY';

      const equipmentRegistryId = payload.equipment_registry_id
        ? await resolveEquipmentRegistryId(payload.equipment_registry_id)
        : order.equipment_registry_id || null;

      const study = await radiologyWorkspaceRepository.txCreateStudy(tx, {
        radiology_order_id: order.id,
        modality,
        room:
          payload.room == null
            ? order.room || null
            : String(payload.room || '').trim() || null,
        equipment_registry_id: equipmentRegistryId,
        performed_at: toDateOrNull(payload.performed_at, null),
        started_at: toDateOrNull(payload.started_at, toDateOrNull(payload.performed_at, new Date()))});

      // Fold Start imaging into Procedure done: ORDERED → IN_PROCESS when a
      // study is recorded so clients do not need a separate start step.
      if (order.status === 'ORDERED') {
        await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
          status: 'IN_PROCESS'});
      }

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        order: refreshedOrder,
        study};
    });

    createAuditLog({
      user_id: userId,
      action: 'CREATE_STUDY',
      entity: 'imaging_study',
      entity_id: mutation.study?.id,
      diff: {
        metadata: {
          order_id: orderId,
          modality: mutation.study?.modality,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const study = mapImagingStudyRecord(mutation.study);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'CREATE_STUDY',
      resourceType: 'study',
      resourceId: study?.id || null}).catch(() => {});

    return {
      workflow,
      study};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const undoRadiologyStudy = async (identifier, userId, ipAddress) => {
  try {
    const studyId = await resolveModelIdOrThrow({
      identifier,
      model: 'imaging_study',
      where: { deleted_at: null },
      errorKey: 'errors.imaging_study.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const study = await radiologyWorkspaceRepository.txFindStudyById(tx, studyId);
      if (!study) {
        throw new HttpError('errors.imaging_study.not_found', 404);
      }

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        study.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      assertTransition(order.status !== 'CANCELLED' && order.status !== 'COMPLETED', {
        from: order.status,
        to: 'UNDO_STUDY'});

      const hasFinalResult = (order.radiology_results || []).some((result) =>
        ['FINAL', 'AMENDED'].includes(String(result.status || '').toUpperCase())
      );
      assertTransition(!hasFinalResult, {
        from: 'FINAL',
        to: 'UNDO_STUDY'});

      const deletedAt = new Date();
      await radiologyWorkspaceRepository.txSoftDeleteStudyAssets(tx, study.id, deletedAt);
      await radiologyWorkspaceRepository.txSoftDeleteStudyPacsLinks(tx, study.id, deletedAt);
      await radiologyWorkspaceRepository.txSoftDeleteStudy(tx, study.id, deletedAt);

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return { order: refreshedOrder, study };
    });

    createAuditLog({
      user_id: userId,
      action: 'UNDO_STUDY',
      entity: 'imaging_study',
      entity_id: mutation.study?.id,
      diff: {
        metadata: {
          order_id: mutation.order?.id}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'UNDO_STUDY',
      resourceType: 'study',
      resourceId: mutation.study?.id || null}).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const undoRadiologyDraftResult = async (identifier, userId, ipAddress) => {
  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const result = await radiologyWorkspaceRepository.txFindResultById(tx, resultId);
      if (!result) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      const status = String(result.status || '').trim().toUpperCase();
      assertTransition(status === 'DRAFT', {
        from: status || 'UNKNOWN',
        to: 'UNDO_DRAFT'});

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        result.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      assertTransition(order.status !== 'CANCELLED' && order.status !== 'COMPLETED', {
        from: order.status,
        to: 'UNDO_DRAFT'});

      await radiologyWorkspaceRepository.txSoftDeleteResult(tx, result.id);

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return { order: refreshedOrder, result };
    });

    createAuditLog({
      user_id: userId,
      action: 'UNDO_DRAFT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          order_id: mutation.order?.id}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'UNDO_DRAFT',
      resourceType: 'result',
      resourceId: mutation.result?.id || null}).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const initStudyAssetUpload = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const studyId = await resolveModelIdOrThrow({
      identifier,
      model: 'imaging_study',
      where: { deleted_at: null },
      errorKey: 'errors.imaging_study.not_found'});

    const study = await radiologyWorkspaceRepository.findStudyById(
      studyId,
      RADIOLOGY_STUDY_WITH_RELATIONS_INCLUDE
    );
    if (!study) {
      throw new HttpError('errors.imaging_study.not_found', 404);
    }

    const storageKey = buildUploadStorageKey(study.id, payload.file_name);
    const uploadToken = crypto.randomUUID();

    createAuditLog({
      user_id: userId,
      action: 'INIT_UPLOAD',
      entity: 'imaging_asset',
      entity_id: study.id,
      diff: {
        metadata: {
          imaging_study_id: study.id,
          file_name: payload.file_name,
          content_type: payload.content_type || null,
          size_bytes: payload.size_bytes || null,
          storage_key: storageKey,
          storage_provider: STORAGE_PROVIDER}},
      ip_address: ipAddress}).catch(() => {});

    const studyPublicId = toPublicIdentifier(study.human_friendly_id, study.id);
    // Controlled storage handoff: clients must commit through the authenticated
    // workspace endpoint (no unrestricted filesystem/object paths).
    const controlledUploadPath = `/api/v1/radiology/studies/${studyPublicId}/assets/commit-upload`;

    return {
      imaging_study_id: studyPublicId,
      upload_token: uploadToken,
      storage_key: storageKey,
      storage_provider: STORAGE_PROVIDER,
      storage_mode: 'controlled',
      upload_url: controlledUploadPath,
      upload_method: 'POST',
      headers: {
        'content-type': 'application/json'},
      expires_in_seconds: 900};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const commitStudyAssetUpload = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const studyId = await resolveModelIdOrThrow({
      identifier,
      model: 'imaging_study',
      where: { deleted_at: null },
      errorKey: 'errors.imaging_study.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const study = await radiologyWorkspaceRepository.txFindStudyById(
        tx,
        studyId,
        RADIOLOGY_STUDY_WITH_RELATIONS_INCLUDE
      );
      if (!study) {
        throw new HttpError('errors.imaging_study.not_found', 404);
      }

      const storageKey = String(payload.storage_key || '').trim();
      const expectedPrefix = `radiology/${sanitizeForPath(study.id)}/`;
      if (!storageKey || !storageKey.startsWith(expectedPrefix) || storageKey.includes('..')) {
        throw new HttpError('errors.validation.invalid', 400, [
          { field: 'storage_key', reason: 'unrestricted_storage_path' }]);
      }

      const existingAsset = await radiologyWorkspaceRepository.txFindFirstAsset(tx, {
        imaging_study_id: study.id,
        storage_key: storageKey});

      const asset = existingAsset
        ? existingAsset
        : await radiologyWorkspaceRepository.txCreateAsset(tx, {
            imaging_study_id: study.id,
            storage_key: storageKey,
            file_name: payload.file_name || null,
            content_type: payload.content_type || null});

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        study.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        order,
        study,
        asset};
    });

    createAuditLog({
      user_id: userId,
      action: 'COMMIT_UPLOAD',
      entity: 'imaging_asset',
      entity_id: mutation.asset?.id,
      diff: {
        metadata: {
          imaging_study_id: mutation.study?.id,
          storage_key: mutation.asset?.storage_key,
          file_name: mutation.asset?.file_name || null,
          content_type: mutation.asset?.content_type || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const assetId = toPublicIdentifier(mutation.asset?.human_friendly_id, mutation.asset?.id);

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'COMMIT_UPLOAD',
      resourceType: 'asset',
      resourceId: assetId}).catch(() => {});

    return {
      workflow,
      asset: {
        id: assetId,
        display_id: assetId,
        storage_key: mutation.asset?.storage_key || null,
        file_name: mutation.asset?.file_name || null,
        content_type: mutation.asset?.content_type || null,
        created_at: mutation.asset?.created_at ? new Date(mutation.asset.created_at).toISOString() : null}};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const syncStudyToPacs = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const studyId = await resolveModelIdOrThrow({
      identifier,
      model: 'imaging_study',
      where: { deleted_at: null },
      errorKey: 'errors.imaging_study.not_found'});

    const study = await radiologyWorkspaceRepository.findStudyById(
      studyId,
      RADIOLOGY_STUDY_WITH_RELATIONS_INCLUDE
    );
    if (!study) {
      throw new HttpError('errors.imaging_study.not_found', 404);
    }

    const orderRecord = await radiologyWorkspaceRepository.findOrderById(
      study.radiology_order_id,
      RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
    );
    if (!orderRecord) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }
    let workflowOrderRecord = orderRecord;

    let syncStatus = 'PENDING';
    let syncError = null;
    let pacsLinkRecord = null;
    let pacsResponse = null;

    try {
      if (!dicomWebClient.isConfigured()) {
        throw new Error('PACS_DICOMWEB_BASE_URL is not configured');
      }

      pacsResponse = await dicomWebClient.stowStudy({
        studyUid: payload.study_uid || null,
        metadata: Array.isArray(payload.metadata) ? payload.metadata : [],
        instances: Array.isArray(payload.instances) ? payload.instances : []});

      const resolvedStudyUid =
        pacsResponse?.studyUid ||
        payload.study_uid ||
        toPublicIdentifier(study.human_friendly_id, study.id);
      const studyUrl = dicomWebClient.buildStudyUrl(resolvedStudyUid);

      const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
        const link = await radiologyWorkspaceRepository.txCreatePacsLink(tx, {
          imaging_study_id: study.id,
          url: studyUrl,
          expires_at: null});

        const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
          tx,
          study.radiology_order_id,
          RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
        );

        return {
          link,
          order: refreshedOrder};
      });

      pacsLinkRecord = mutation.link;
      syncStatus = 'SUCCESS';
      workflowOrderRecord = mutation.order;

      const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
      publishRadiologyRealtimeUpdates({
        workflow,
        orderRecord: mutation.order,
        actorUserId: userId || null,
        action: 'PACS_SYNC',
        resourceType: 'study',
        resourceId: toPublicIdentifier(study.human_friendly_id, study.id)}).catch(() => {});
    } catch (error) {
      syncStatus = 'FAILED';
      syncError = error.message;
    }

    createAuditLog({
      user_id: userId,
      action: 'PACS_SYNC',
      entity: 'imaging_study',
      entity_id: study.id,
      diff: {
        metadata: {
          imaging_study_id: study.id,
          status: syncStatus,
          study_uid: payload.study_uid || pacsResponse?.studyUid || null,
          error: syncError,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(workflowOrderRecord);
    return {
      workflow,
      sync_status: syncStatus,
      pacs_link: pacsLinkRecord ? mapPacsLinkRecord(pacsLinkRecord) : null,
      error: syncError,
      response: pacsResponse};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const draftRadiologyResult = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      assertTransition(order.status !== 'CANCELLED', {
        from: order.status,
        to: 'DRAFT_RESULT'});

      const existingDraft = await radiologyWorkspaceRepository.txFindFirstResult(tx, {
        radiology_order_id: order.id,
        status: 'DRAFT'});
      const reportText = composeReportText({
        reportText: payload.report_text,
        findings: payload.findings,
        impression: payload.impression});

      const result = existingDraft
        ? await radiologyWorkspaceRepository.txUpdateResult(tx, existingDraft.id, {
            report_text: reportText ?? existingDraft.report_text,
            reported_at: toDateOrNull(payload.reported_at, existingDraft.reported_at || null)})
        : await radiologyWorkspaceRepository.txCreateResult(tx, {
            radiology_order_id: order.id,
            status: 'DRAFT',
            report_text: reportText,
            report_version:
              (Array.isArray(order.results)
                ? order.results.reduce(
                    (max, entry) => Math.max(max, Number(entry.report_version) || 0),
                    0
                  )
                : 0) + 1,
            reported_at: toDateOrNull(payload.reported_at, null)});

      if (order.status === 'ORDERED') {
        await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
          status: 'IN_PROCESS'});
      }

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        order: refreshedOrder,
        result};
    });

    createAuditLog({
      user_id: userId,
      action: 'DRAFT_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          order_id: orderId}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order});

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'DRAFT_RESULT',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result}).catch(() => {});

    return {
      workflow,
      result};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const finalizeRadiologyResult = async (identifier, payload = {}, userId, ipAddress) => {
  if (RADIOLOGY_ATTESTATION_V2) {
    return attestRadiologyResultFinalization(
      identifier,
      {
        report_text: payload.report_text,
        reported_at: payload.reported_at,
        notes: payload.notes},
      userId,
      null,
      ipAddress
    );
  }

  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const result = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        resultId,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );
      if (!result) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      if (result.status === 'FINAL') {
        const order = await radiologyWorkspaceRepository.txFindOrderById(
          tx,
          result.radiology_order_id,
          RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
        );
        return {
          result,
          order};
      }

      assertTransition(result.status === 'DRAFT', {
        from: result.status,
        to: 'FINAL'});

      const updatedResult = await radiologyWorkspaceRepository.txUpdateResult(tx, result.id, {
        status: 'FINAL',
        report_text: payload.report_text || result.report_text || null,
        reported_at: toDateOrNull(payload.reported_at, new Date())});

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        result.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        result: updatedResult,
        order};
    });

    createAuditLog({
      user_id: userId,
      action: 'FINALIZE_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order});

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'FINALIZE_RESULT',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result}).catch(() => {});

    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'RADIOLOGY_RESULT_FINALIZED'});

    return {
      workflow,
      result};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const requestRadiologyResultFinalization = async (
  identifier,
  payload = {},
  userId,
  userRole,
  ipAddress
) => {
  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const result = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        resultId,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );
      if (!result) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      assertTransition(result.status === 'DRAFT', {
        from: result.status,
        to: 'REQUEST_FINALIZATION'});

      const existingRequest = await radiologyWorkspaceRepository.txFindResultAttestation(
        tx,
        result.id,
        'REQUEST'
      );

      if (!existingRequest) {
        await createResultAttestation({
          tx,
          resultId: result.id,
          phase: 'REQUEST',
          userId,
          userRole,
          statement: payload.statement,
          reason: payload.reason,
          ipAddress,
          attestedAt: payload.requested_at});
      }

      const refreshedResult = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        result.id,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        result.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        result: refreshedResult,
        order};
    });

    createAuditLog({
      user_id: userId,
      action: 'REQUEST_FINALIZE_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          reason: payload.reason || null,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order});

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'REQUEST_FINALIZATION',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result}).catch(() => {});

    return {
      workflow,
      result};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const attestRadiologyResultFinalization = async (
  identifier,
  payload = {},
  userId,
  userRole,
  ipAddress
) => {
  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const result = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        resultId,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );
      if (!result) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      assertTransition(['DRAFT', 'FINAL'].includes(result.status), {
        from: result.status,
        to: 'ATTEST_FINALIZATION'});

      const requestAttestation = await radiologyWorkspaceRepository.txFindResultAttestation(
        tx,
        result.id,
        'REQUEST'
      );
      assertTransition(Boolean(requestAttestation), {
        reason: 'request_finalization_required',
        result_id: result.id});

      if (String(requestAttestation.attested_by_user_id || '') === String(userId || '')) {
        throw new HttpError('errors.radiology_workspace.attestation.same_user', 400);
      }

      const existingAttestation = await radiologyWorkspaceRepository.txFindResultAttestation(
        tx,
        result.id,
        'ATTEST'
      );

      let updatedResult = result;
      if (!existingAttestation && result.status !== 'FINAL') {
        updatedResult = await radiologyWorkspaceRepository.txUpdateResult(tx, result.id, {
          status: 'FINAL',
          report_text: payload.report_text || result.report_text || null,
          reported_at: toDateOrNull(payload.reported_at, new Date())});
      }

      if (!existingAttestation) {
        await createResultAttestation({
          tx,
          resultId: result.id,
          phase: 'ATTEST',
          userId,
          userRole,
          statement: payload.statement,
          reason: payload.reason,
          ipAddress,
          attestedAt: payload.attested_at});
      }

      const refreshedResult = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        result.id,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        updatedResult.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        result: refreshedResult,
        order};
    });

    createAuditLog({
      user_id: userId,
      action: 'ATTEST_FINALIZE_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          reason: payload.reason || null,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order});

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'ATTEST_FINALIZATION',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result}).catch(() => {});

    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'RADIOLOGY_RESULT_ATTESTED'});

    return {
      workflow,
      result};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const addendumRadiologyResult = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found'});

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const baseResult = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        resultId,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );
      if (!baseResult) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      assertTransition(baseResult.status === 'FINAL' || baseResult.status === 'AMENDED', {
        from: baseResult.status,
        to: 'AMENDED'});

      // Never mutate the finalized/amended source row; append a new version.
      const orderForVersion = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        baseResult.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      const nextVersion =
        (Array.isArray(orderForVersion?.results)
          ? orderForVersion.results.reduce(
              (max, entry) => Math.max(max, Number(entry.report_version) || 0),
              0
            )
          : Number(baseResult.report_version) || 1) + 1;

      const addendumText = String(payload.addendum_text || '').trim();
      const amendedResult = await radiologyWorkspaceRepository.txCreateResult(tx, {
        radiology_order_id: baseResult.radiology_order_id,
        parent_result_id: baseResult.id,
        status: 'AMENDED',
        addendum_text: addendumText,
        report_text: composeAddendumText(baseResult.report_text, addendumText),
        report_version: nextVersion,
        reported_at: toDateOrNull(payload.reported_at, new Date())});

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        baseResult.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        result: amendedResult,
        order,
        baseResult};
    });

    createAuditLog({
      user_id: userId,
      action: 'ADDENDUM_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          base_result_id: mutation.baseResult?.id || resultId,
          parent_result_id: mutation.result?.parent_result_id || null,
          report_version: mutation.result?.report_version || null,
          notes: payload.notes || null}},
      ip_address: ipAddress}).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order});

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'ADDENDUM_RESULT',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result}).catch(() => {});

    syncOpdFlowForOrder(mutation.order, {
      userId,
      trigger: 'RADIOLOGY_RESULT_AMENDED'});

    return {
      workflow,
      result};
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

    const publicIdentifier = toPublicIdentifier(record?.human_friendly_id, normalizedIdentifier);
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
      matched_by: isUuidLike(normalizedIdentifier) ? 'uuid' : 'human_friendly_id'};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  getRadiologyWorkbench,
  getRadiologyReferenceData,
  createRadiologyOrder,
  getRadiologyOrderWorkflow,
  updateRadiologyOrderRequestDetails,
  assignRadiologyOrder,
  startRadiologyOrder,
  completeRadiologyOrder,
  cancelRadiologyOrder,
  createRadiologyStudy,
  undoRadiologyStudy,
  undoRadiologyDraftResult,
  initStudyAssetUpload,
  commitStudyAssetUpload,
  syncStudyToPacs,
  draftRadiologyResult,
  finalizeRadiologyResult,
  requestRadiologyResultFinalization,
  attestRadiologyResultFinalization,
  addendumRadiologyResult,
  resolveLegacyRouteIdentifier};
