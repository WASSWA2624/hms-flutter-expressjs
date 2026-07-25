const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  mapClinicalOrderBillingFields,
  mapCatalogUnitPriceFields,
  extractStoredClinicalBilling} = require('@lib/billing/clinical-request-billing');

const toText = (value) => (value == null ? '' : String(value).trim());

/** Payment statuses that allow radiology study execution to proceed. */
const RADIOLOGY_PAYMENT_SATISFIED_STATUSES = new Set([
  'PAID',
  'NOT_REQUIRED',
  'NO_CHARGE',
  'NOT_BILLED']);

const resolveRadiologyOrderPaymentStatus = (order = {}) => {
  const billingFields = mapClinicalOrderBillingFields(order);
  const direct = toText(billingFields.payment_status).toUpperCase();
  if (direct) return direct;
  const billing = extractStoredClinicalBilling(order);
  return toText(billing?.payment_status).toUpperCase() || null;
};

const isRadiologyOrderPaymentSatisfied = (order = {}) => {
  const status = resolveRadiologyOrderPaymentStatus(order);
  if (!status) return true;
  return RADIOLOGY_PAYMENT_SATISFIED_STATUSES.has(status);
};

const toPublicIdentifier = (...candidates) => {
  for (const candidate of candidates) {
    const normalized = toText(candidate);
    if (!normalized) continue;
    if (isUuidLike(normalized)) continue;
    return normalized;
  }
  return null;
};

const toIsoDateTime = (value) => {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
};

const toDisplayName = (...segments) => {
  const value = segments.map(toText).filter(Boolean).join(' ').trim();
  return value || null;
};

const mapRadiologyTestRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    name: toText(record.name) || null,
    code: toText(record.code) || null,
    modality: toText(record.modality).toUpperCase() || null,
    body_region: toText(record.body_region) || null,
    laterality: toText(record.laterality) || null,
    equipment: toText(record.equipment) || null,
    procedure_type: toText(record.procedure_type) || null,
    ...mapCatalogUnitPriceFields(record),
    tenant_id: toPublicIdentifier(record.tenant?.human_friendly_id, record.tenant_id),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapImagingAssetRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    imaging_study_id: toPublicIdentifier(
      record.imaging_study?.human_friendly_id,
      record.imaging_study_id
    ),
    storage_key: toText(record.storage_key) || null,
    file_name: toText(record.file_name) || null,
    content_type: toText(record.content_type) || null,
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapEquipmentRegistrySummary = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const name =
    toText(record.equipment_name) ||
    toText(record.name) ||
    toText(record.equipment_code) ||
    null;
  return {
    id: publicId,
    display_id: publicId,
    equipment_name: name,
    equipment_code: toText(record.equipment_code) || null,
    status: toText(record.status) || null};
};

const mapPacsLinkRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    imaging_study_id: toPublicIdentifier(
      record.imaging_study?.human_friendly_id,
      record.imaging_study_id
    ),
    url: toText(record.url) || null,
    expires_at: toIsoDateTime(record.expires_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapImagingStudyRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const assets = Array.isArray(record.assets)
    ? record.assets.map(mapImagingAssetRecord).filter(Boolean)
    : [];
  const pacsLinks = Array.isArray(record.pacs_links)
    ? record.pacs_links.map(mapPacsLinkRecord).filter(Boolean)
    : [];

  const equipment = mapEquipmentRegistrySummary(record.equipment_registry);

  return {
    id: publicId,
    display_id: publicId,
    radiology_order_id: toPublicIdentifier(
      record.radiology_order?.human_friendly_id,
      record.radiology_order_id
    ),
    modality: toText(record.modality).toUpperCase() || null,
    room: toText(record.room) || null,
    equipment_registry_id: toPublicIdentifier(
      record.equipment_registry?.human_friendly_id,
      record.equipment_registry_id
    ),
    equipment_display_name: equipment?.equipment_name || null,
    performed_at: toIsoDateTime(record.performed_at),
    started_at: toIsoDateTime(record.started_at),
    completed_at: toIsoDateTime(record.completed_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
    asset_count: assets.length,
    pacs_link_count: pacsLinks.length,
    last_pacs_url: toText(pacsLinks[0]?.url) || null,
    assets,
    pacs_links: pacsLinks};
};

const mapRadiologyResultAttestationRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    radiology_result_id: toPublicIdentifier(
      record.radiology_result?.human_friendly_id,
      record.radiology_result_id
    ),
    phase: toText(record.phase).toUpperCase() || null,
    attested_by_user_id: toPublicIdentifier(record.attested_by_user_id),
    attested_role: toText(record.attested_role) || null,
    statement: toText(record.statement) || null,
    reason: toText(record.reason) || null,
    attested_at: toIsoDateTime(record.attested_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapRadiologyResultRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const order = record.radiology_order;
  const patient = order?.patient;
  const test = order?.radiology_procedure || order?.radiology_test;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const attestations = Array.isArray(record.attestations)
    ? record.attestations.map(mapRadiologyResultAttestationRecord).filter(Boolean)
    : [];
  const requestAttestation = attestations.find((entry) => entry.phase === 'REQUEST') || null;
  const attestAttestation = attestations.find((entry) => entry.phase === 'ATTEST') || null;

  return {
    id: publicId,
    display_id: publicId,
    radiology_order_id: toPublicIdentifier(order?.human_friendly_id, record.radiology_order_id),
    parent_result_id: toPublicIdentifier(
      record.parent_result?.human_friendly_id,
      record.parent_result_id
    ),
    patient_id: toPublicIdentifier(patient?.human_friendly_id, order?.patient_id),
    patient_display_name: toDisplayName(patient?.first_name, patient?.last_name),
    radiology_procedure_id: toPublicIdentifier(test?.human_friendly_id, order?.radiology_procedure_id || order?.radiology_test_id),
    radiology_test_id: toPublicIdentifier(test?.human_friendly_id, order?.radiology_procedure_id || order?.radiology_test_id),
    test_display_name:
      toText(test?.name) ||
      toText(test?.code) ||
      toText(order?.request_details?.new_test_name) ||
      null,
    modality:
      toText((order?.radiology_procedure || order?.radiology_test)?.modality).toUpperCase() ||
      toText(order?.request_details?.modality).toUpperCase() ||
      toText(order?.imaging_studies?.[0]?.modality).toUpperCase() ||
      null,
    status: toText(record.status).toUpperCase() || null,
    report_text: toText(record.report_text) || null,
    addendum_text: toText(record.addendum_text) || null,
    report_version: Number.isFinite(Number(record.report_version))
      ? Number(record.report_version)
      : 1,
    finalization: {
      requested: Boolean(requestAttestation),
      requested_at: requestAttestation?.attested_at || null,
      requested_by_role: requestAttestation?.attested_role || null,
      attested: Boolean(attestAttestation),
      attested_at: attestAttestation?.attested_at || null,
      attested_by_role: attestAttestation?.attested_role || null,
      pending_attestation: Boolean(requestAttestation) && !Boolean(attestAttestation)},
    attestations,
    reported_at: toIsoDateTime(record.reported_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapRadiologyOrderRecord = (record, options = {}) => {
  if (!record || typeof record !== 'object') return null;
  const { includeChildren = true } = options;
  const patient = record.patient;
  const encounter = record.encounter;
  const test = record.radiology_procedure || record.radiology_test;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const requestDetails =
    record.request_details &&
    typeof record.request_details === 'object' &&
    !Array.isArray(record.request_details)
      ? record.request_details
      : {};
  const storedBilling = extractStoredClinicalBilling(record);
  const testDisplayName =
    toText(test?.name) ||
    toText(test?.code) ||
    toText(requestDetails.new_test_name) ||
    toText(requestDetails.name) ||
    null;
  const modality =
    toText(test?.modality).toUpperCase() ||
    toText(requestDetails.modality).toUpperCase() ||
    null;

  const results = includeChildren && Array.isArray(record.results)
    ? record.results
        .map((entry) => mapRadiologyResultRecord({ ...entry, radiology_order: record }))
        .filter(Boolean)
    : [];
  const studies = includeChildren && Array.isArray(record.imaging_studies)
    ? record.imaging_studies.map((entry) => mapImagingStudyRecord({
        ...entry,
        radiology_order: record})).filter(Boolean)
    : [];

  const finalResultCount = results.filter((entry) => entry.status === 'FINAL').length;
  const amendedResultCount = results.filter((entry) => entry.status === 'AMENDED').length;
  const draftResultCount = results.filter((entry) => entry.status === 'DRAFT').length;
  const unsyncedStudyCount = studies.filter((entry) => Number(entry.pacs_link_count || 0) === 0).length;
  const assignedUser = record.assigned_user;
  const equipment = mapEquipmentRegistrySummary(record.equipment_registry);
  const paymentSatisfied = isRadiologyOrderPaymentSatisfied(record);

  return {
    id: publicId,
    display_id: publicId,
    status: toText(record.status).toUpperCase() || null,
    encounter_id: toPublicIdentifier(encounter?.human_friendly_id, record.encounter_id),
    patient_id: toPublicIdentifier(patient?.human_friendly_id, record.patient_id),
    patient_display_name: toDisplayName(patient?.first_name, patient?.last_name),
    radiology_procedure_id: toPublicIdentifier(test?.human_friendly_id, record.radiology_procedure_id || record.radiology_test_id),
    radiology_test_id: toPublicIdentifier(test?.human_friendly_id, record.radiology_procedure_id || record.radiology_test_id),
    test_display_name: testDisplayName,
    radiology_test_display_name: testDisplayName,
    modality,
    clinical_note: toText(record.clinical_note) || null,
    assigned_user_id: toPublicIdentifier(
      assignedUser?.human_friendly_id,
      record.assigned_user_id
    ),
    assigned_user_display_name: toDisplayName(
      assignedUser?.profile?.first_name,
      assignedUser?.profile?.last_name,
      assignedUser?.email
    ),
    scheduled_at: toIsoDateTime(record.scheduled_at),
    room: toText(record.room) || null,
    equipment_registry_id: toPublicIdentifier(
      record.equipment_registry?.human_friendly_id,
      record.equipment_registry_id
    ),
    equipment_display_name: equipment?.equipment_name || null,
    request_details: {
      ...requestDetails,
      radiology_procedure_id: toPublicIdentifier(
        test?.human_friendly_id,
        requestDetails.radiology_procedure_id || requestDetails.radiology_test_id
      ),
      radiology_test_id: toPublicIdentifier(
        test?.human_friendly_id,
        requestDetails.radiology_procedure_id || requestDetails.radiology_test_id
      ),
      new_test_name: toText(requestDetails.new_test_name) || null,
      modality,
      ...(storedBilling ? { billing: storedBilling } : {})},
    requested_tests: [
      {
        radiology_procedure_id: toPublicIdentifier(test?.human_friendly_id, record.radiology_procedure_id || record.radiology_test_id),
        radiology_test_id: toPublicIdentifier(test?.human_friendly_id, record.radiology_procedure_id || record.radiology_test_id),
        radiology_test_display_name: testDisplayName,
        test_display_name: testDisplayName,
        modality,
        body_region: toText(requestDetails.body_region) || null,
        laterality: toText(requestDetails.laterality) || null,
        priority: toText(requestDetails.priority) || null}].filter(
      (entry) => entry.radiology_procedure_id || entry.radiology_test_id || entry.test_display_name || entry.modality
    ),
    ordered_at: toIsoDateTime(record.ordered_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
    result_count: results.length,
    draft_result_count: draftResultCount,
    final_result_count: finalResultCount,
    amended_result_count: amendedResultCount,
    study_count: studies.length,
    unsynced_study_count: unsyncedStudyCount,
    results,
    imaging_studies: studies,
    billing_gate_blocked: !paymentSatisfied,
    ...mapClinicalOrderBillingFields(record)};
};

const mapRadiologyOrderWorkflowRecord = (record) => {
  const order = mapRadiologyOrderRecord(record, { includeChildren: true });
  if (!order) return null;

  const timeline = [
    {
      id: 'order-placed',
      type: 'ORDER_PLACED',
      at: order.ordered_at || order.created_at,
      label: 'Radiology order created'}];

  order.imaging_studies.forEach((study, index) => {
    if (study.performed_at) {
      timeline.push({
        id: `study-performed-${study.id || index}`,
        type: 'STUDY_PERFORMED',
        at: study.performed_at,
        label: `Study ${study.display_id || index + 1} performed`});
    }

    study.assets.forEach((asset, assetIndex) => {
      timeline.push({
        id: `asset-uploaded-${asset.id || `${study.id}-${assetIndex}`}`,
        type: 'ASSET_UPLOADED',
        at: asset.created_at,
        label: `Asset ${asset.file_name || asset.display_id || assetIndex + 1} captured`});
    });

    study.pacs_links.forEach((link, linkIndex) => {
      timeline.push({
        id: `pacs-synced-${link.id || `${study.id}-${linkIndex}`}`,
        type: 'PACS_SYNCED',
        at: link.created_at,
        label: `Study ${study.display_id || index + 1} synced to PACS`});
    });
  });

  order.results.forEach((result, index) => {
    timeline.push({
      id: `result-${result.id || index}`,
      type: `RESULT_${toText(result.status).toUpperCase() || 'UPDATED'}`,
      at: result.reported_at || result.updated_at || result.created_at,
      label: `Report ${result.status || 'updated'} for ${order.test_display_name || 'study'}`});
  });

  timeline.sort((a, b) => {
    const left = Date.parse(a.at || '');
    const right = Date.parse(b.at || '');
    if (!Number.isFinite(left) && !Number.isFinite(right)) return 0;
    if (!Number.isFinite(left)) return 1;
    if (!Number.isFinite(right)) return -1;
    return left - right;
  });

  const hasFinalResult = order.results.some((entry) => entry.status === 'FINAL');
  const hasDraftResult = order.results.some((entry) => entry.status === 'DRAFT');
  const hasPendingResultAttestation = order.results.some(
    (entry) => entry.finalization?.pending_attestation
  );
  const paymentSatisfied = !order.billing_gate_blocked;
  const isActive = order.status !== 'CANCELLED';
  const isAssignable = ['ORDERED', 'IN_PROCESS'].includes(order.status);
  const hasAssignment = Boolean(
    order.assigned_user_id || order.scheduled_at || order.room || order.equipment_registry_id
  );

  if (order.scheduled_at || hasAssignment) {
    timeline.push({
      id: 'order-scheduled',
      type: 'ORDER_SCHEDULED',
      at: order.scheduled_at || order.updated_at || order.ordered_at,
      label: 'Study scheduled / assigned'});
    timeline.sort((a, b) => {
      const left = Date.parse(a.at || '');
      const right = Date.parse(b.at || '');
      if (!Number.isFinite(left) && !Number.isFinite(right)) return 0;
      if (!Number.isFinite(left)) return 1;
      if (!Number.isFinite(right)) return -1;
      return left - right;
    });
  }

  return {
    order,
    results: order.results,
    studies: order.imaging_studies,
    timeline,
    next_actions: {
      can_assign: isAssignable,
      can_start: order.status === 'ORDERED' && paymentSatisfied,
      can_complete: order.status === 'IN_PROCESS' && hasFinalResult,
      can_cancel: ['ORDERED', 'IN_PROCESS'].includes(order.status),
      can_create_study: isActive && paymentSatisfied,
      can_create_draft_result: isActive && paymentSatisfied,
      can_finalize_result: hasDraftResult && paymentSatisfied,
      can_request_finalization: hasDraftResult && paymentSatisfied,
      can_attest_finalization: hasPendingResultAttestation,
      can_add_addendum: hasFinalResult,
      can_pacs_sync: order.imaging_studies.some((study) => study.asset_count > 0),
      billing_gate_blocked: !paymentSatisfied,
      has_assignment: hasAssignment}};
};

module.exports = {
  toPublicIdentifier,
  toIsoDateTime,
  isRadiologyOrderPaymentSatisfied,
  resolveRadiologyOrderPaymentStatus,
  mapRadiologyTestRecord,
  mapRadiologyOrderRecord,
  mapRadiologyResultRecord,
  mapRadiologyResultAttestationRecord,
  mapImagingStudyRecord,
  mapImagingAssetRecord,
  mapPacsLinkRecord,
  mapRadiologyOrderWorkflowRecord};
