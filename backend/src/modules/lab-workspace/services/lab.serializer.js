const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  buildLabReferenceRangeRowSummary,
  buildLabReferenceRangeSummary,
} = require('@services/lab-workspace/lab.configuration');

const toText = (value) => (value == null ? '' : String(value).trim());

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

const RESULT_REOPENABLE_STATES = new Set(['NORMAL', 'ABNORMAL', 'CRITICAL']);
const REVERSE_STEP_PRIORITY = Object.freeze({
  COLLECT: 1,
  REJECT: 2,
  RECEIVE: 3,
  RELEASE: 4,
});

const toTimestampValue = (...candidates) => {
  for (const candidate of candidates) {
    const normalized = candidate instanceof Date ? candidate : candidate ? new Date(candidate) : null;
    const timestamp = normalized?.getTime?.() ?? Number.NaN;
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

const resolveLatestReverseWorkflowTarget = (record) => {
  if (!record || typeof record !== 'object') return null;

  let latest = null;

  (record.items || []).forEach((item) => {
    if (toText(item?.status).toUpperCase() !== 'COMPLETED') return;
    (item?.results || []).forEach((result) => {
      if (!RESULT_REOPENABLE_STATES.has(toText(result?.status).toUpperCase())) return;
      latest = selectLatestReverseCandidate(latest, {
        kind: 'RELEASE',
        atMs: toTimestampValue(result?.reported_at, result?.updated_at),
      });
    });
  });

  (record.samples || []).forEach((sample) => {
    const sampleStatus = toText(sample?.status).toUpperCase();
    if (sampleStatus === 'RECEIVED') {
      latest = selectLatestReverseCandidate(latest, {
        kind: 'RECEIVE',
        atMs: toTimestampValue(sample?.received_at, sample?.updated_at),
      });
      return;
    }
    if (sampleStatus === 'REJECTED') {
      latest = selectLatestReverseCandidate(latest, {
        kind: 'REJECT',
        atMs: toTimestampValue(sample?.updated_at, sample?.received_at, sample?.collected_at),
      });
      return;
    }
    if (sampleStatus === 'COLLECTED') {
      latest = selectLatestReverseCandidate(latest, {
        kind: 'COLLECT',
        atMs: toTimestampValue(sample?.collected_at, sample?.updated_at),
      });
    }
  });

  return latest;
};

const toLabOrderStatusRank = (status) => {
  const normalized = toText(status).toUpperCase();
  if (normalized === 'CANCELLED') return 4;
  if (normalized === 'COMPLETED') return 3;
  if (normalized === 'IN_PROCESS') return 2;
  if (normalized === 'COLLECTED') return 1;
  return 0;
};

const toNumericText = (value) => {
  const normalized = toText(value);
  return normalized || null;
};

const mapLabReferenceRangeRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  return {
    id: toPublicIdentifier(record.human_friendly_id, record.id) || toText(record.id) || null,
    label: toText(record.label) || null,
    unit: toText(record.unit) || null,
    gender: toText(record.gender) || null,
    age_min_value:
      Number.isFinite(Number(record.age_min_value)) ? Number(record.age_min_value) : null,
    age_min_unit: toText(record.age_min_unit) || null,
    age_max_value:
      Number.isFinite(Number(record.age_max_value)) ? Number(record.age_max_value) : null,
    age_max_unit: toText(record.age_max_unit) || null,
    normal_min_value: toNumericText(record.normal_min_value),
    normal_max_value: toNumericText(record.normal_max_value),
    critical_min_value: toNumericText(record.critical_min_value),
    critical_max_value: toNumericText(record.critical_max_value),
    reference_text: toText(record.reference_text) || null,
    notes: toText(record.notes) || null,
    sort_order:
      Number.isFinite(Number(record.sort_order)) ? Number(record.sort_order) : 0,
    summary: buildLabReferenceRangeRowSummary(record) || null,
  };
};

const mapLabUnitOptionRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  return {
    id: toPublicIdentifier(record.human_friendly_id, record.id) || toText(record.id) || null,
    label: toText(record.label) || null,
    unit: toText(record.unit) || null,
    ucum_code: toText(record.ucum_code) || null,
    is_default: Boolean(record.is_default),
    sort_order:
      Number.isFinite(Number(record.sort_order)) ? Number(record.sort_order) : 0,
  };
};

const mapLabResultOptionRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const aliases = Array.isArray(record.aliases_json)
    ? record.aliases_json.map((entry) => toText(entry)).filter(Boolean)
    : [];
  return {
    id: toPublicIdentifier(record.human_friendly_id, record.id) || toText(record.id) || null,
    value: toText(record.value) || null,
    label: toText(record.label) || null,
    aliases,
    aliases_json: aliases,
    status: toText(record.status) || null,
    result_flag: toText(record.result_flag) || null,
    is_positive: Boolean(record.is_positive),
    sort_order:
      Number.isFinite(Number(record.sort_order)) ? Number(record.sort_order) : 0,
  };
};

const mapLabPanelItemRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const test = record.lab_test;
  return {
    id: toPublicIdentifier(record.human_friendly_id, record.id) || toText(record.id) || null,
    lab_test_id: toPublicIdentifier(test?.human_friendly_id, record.lab_test_id),
    test_display_name: toText(test?.name) || toText(test?.code) || null,
    test_code: toText(test?.code) || null,
    unit: toText(test?.unit) || null,
    is_required: typeof record.is_required === 'boolean' ? record.is_required : true,
    instructions: toText(record.instructions) || null,
    sort_order:
      Number.isFinite(Number(record.sort_order)) ? Number(record.sort_order) : 0,
  };
};

const mapLabTestRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const referenceRanges = Array.isArray(record.reference_ranges)
    ? record.reference_ranges.map((entry) => mapLabReferenceRangeRecord(entry)).filter(Boolean)
    : [];
  const unitOptions = Array.isArray(record.unit_options)
    ? record.unit_options.map((entry) => mapLabUnitOptionRecord(entry)).filter(Boolean)
    : [];
  const resultOptions = Array.isArray(record.result_options)
    ? record.result_options.map((entry) => mapLabResultOptionRecord(entry)).filter(Boolean)
    : [];
  return {
    id: publicId,
    display_id: publicId,
    name: toText(record.name) || null,
    code: toText(record.code) || null,
    category: toText(record.category) || null,
    specimen_type: toText(record.specimen_type) || null,
    result_kind: toText(record.result_kind) || null,
    unit: toText(record.unit) || null,
    description: toText(record.description) || null,
    reference_range: buildLabReferenceRangeSummary(record.reference_range, referenceRanges),
    reference_ranges: referenceRanges,
    reference_range_count: referenceRanges.length,
    unit_options: unitOptions,
    unit_option_count: unitOptions.length,
    result_options: resultOptions,
    result_option_count: resultOptions.length,
    tenant_id: toPublicIdentifier(record.tenant?.human_friendly_id, record.tenant_id),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
  };
};

const mapLabPanelRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const panelItems = Array.isArray(record.panel_items)
    ? record.panel_items.map((entry) => mapLabPanelItemRecord(entry)).filter(Boolean)
    : [];
  return {
    id: publicId,
    display_id: publicId,
    name: toText(record.name) || null,
    code: toText(record.code) || null,
    category: toText(record.category) || null,
    description: toText(record.description) || null,
    panel_items: panelItems,
    test_count: panelItems.length,
    tenant_id: toPublicIdentifier(record.tenant?.human_friendly_id, record.tenant_id),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
  };
};

const mapLabOrderItemRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const order = record.lab_order;
  const patient = order?.patient;
  const test = record.lab_test;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const resultStatus = Array.isArray(record.results) && record.results.length
    ? record.results
        .map((entry) => toText(entry?.status).toUpperCase())
        .find(Boolean) || null
    : null;

  return {
    id: publicId,
    display_id: publicId,
    status: toText(record.status) || null,
    result_status: resultStatus,
    lab_order_id: toPublicIdentifier(order?.human_friendly_id, record.lab_order_id),
    lab_test_id: toPublicIdentifier(test?.human_friendly_id, record.lab_test_id),
    patient_id: toPublicIdentifier(patient?.human_friendly_id, order?.patient_id),
    patient_display_name: toDisplayName(patient?.first_name, patient?.last_name),
    test_display_name: toText(test?.name) || toText(test?.code) || null,
    test_code: toText(test?.code) || null,
    category: toText(test?.category) || null,
    specimen_type: toText(test?.specimen_type) || null,
    unit: toText(test?.unit) || null,
    unit_options: Array.isArray(test?.unit_options)
      ? test.unit_options.map((entry) => mapLabUnitOptionRecord(entry)).filter(Boolean)
      : [],
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
  };
};

const mapLabSampleRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const order = record.lab_order;
  const patient = order?.patient;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    status: toText(record.status) || null,
    lab_order_id: toPublicIdentifier(order?.human_friendly_id, record.lab_order_id),
    patient_id: toPublicIdentifier(patient?.human_friendly_id, order?.patient_id),
    patient_display_name: toDisplayName(patient?.first_name, patient?.last_name),
    collected_at: toIsoDateTime(record.collected_at),
    received_at: toIsoDateTime(record.received_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
  };
};

const mapLabResultRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const item = record.lab_order_item;
  const order = item?.lab_order;
  const patient = order?.patient;
  const test = item?.lab_test;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    status: toText(record.status) || null,
    result_value: toText(record.result_value) || null,
    result_unit: toText(record.result_unit) || null,
    result_flag: toText(record.result_flag) || null,
    is_positive: Boolean(record.is_positive),
    reference_range_label: toText(record.reference_range_label) || null,
    reference_range_summary: toText(record.reference_range_summary) || null,
    result_text: toText(record.result_text) || null,
    reported_at: toIsoDateTime(record.reported_at),
    lab_order_item_id: toPublicIdentifier(item?.human_friendly_id, record.lab_order_item_id),
    lab_order_id: toPublicIdentifier(order?.human_friendly_id, item?.lab_order_id),
    lab_test_id: toPublicIdentifier(test?.human_friendly_id, item?.lab_test_id),
    patient_id: toPublicIdentifier(patient?.human_friendly_id, order?.patient_id),
    patient_display_name: toDisplayName(patient?.first_name, patient?.last_name),
    test_display_name: toText(test?.name) || toText(test?.code) || null,
    test_code: toText(test?.code) || null,
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
  };
};

const mapLabQcLogRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const test = record.lab_test;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    status: toText(record.status) || null,
    notes: toText(record.notes) || null,
    lab_test_id: toPublicIdentifier(test?.human_friendly_id, record.lab_test_id),
    test_display_name: toText(test?.name) || toText(test?.code) || null,
    test_code: toText(test?.code) || null,
    logged_at: toIsoDateTime(record.logged_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
  };
};

const mapLabOrderRecord = (record, options = {}) => {
  if (!record || typeof record !== 'object') return null;
  const { includeChildren = true } = options;
  const patient = record.patient;
  const encounter = record.encounter;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);

  const items = includeChildren && Array.isArray(record.items)
    ? record.items.map((entry) => mapLabOrderItemRecord({
        ...entry,
        lab_order: record,
      })).filter(Boolean)
    : [];
  const samples = includeChildren && Array.isArray(record.samples)
    ? record.samples.map((entry) => mapLabSampleRecord({
        ...entry,
        lab_order: record,
      })).filter(Boolean)
    : [];

  const rankedItemStatuses = items.map((entry) => toLabOrderStatusRank(entry?.status));
  const highestItemState = rankedItemStatuses.length ? Math.max(...rankedItemStatuses) : 0;
  const inProgressItems = items.filter((entry) => ['COLLECTED', 'IN_PROCESS'].includes(toText(entry?.status).toUpperCase())).length;
  const pendingItems = items.filter((entry) => toText(entry?.status).toUpperCase() === 'ORDERED').length;
  const completedItems = items.filter((entry) => toText(entry?.status).toUpperCase() === 'COMPLETED').length;

  return {
    id: publicId,
    display_id: publicId,
    status: toText(record.status) || null,
    status_rank: Math.max(toLabOrderStatusRank(record.status), highestItemState),
    encounter_id: toPublicIdentifier(encounter?.human_friendly_id, record.encounter_id),
    patient_id: toPublicIdentifier(patient?.human_friendly_id, record.patient_id),
    patient_display_name: toDisplayName(patient?.first_name, patient?.last_name),
    ordered_at: toIsoDateTime(record.ordered_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
    item_count: items.length,
    pending_item_count: pendingItems,
    in_process_item_count: inProgressItems,
    completed_item_count: completedItems,
    sample_count: samples.length,
    items,
    samples,
  };
};

const mapLabOrderWorkflowRecord = (record) => {
  const order = mapLabOrderRecord(record, { includeChildren: true });
  if (!order) return null;
  const timeline = [
    {
      id: 'ordered',
      type: 'ORDER_PLACED',
      at: order.ordered_at || order.created_at,
      label: 'Order requested',
    },
  ];

  order.samples.forEach((sample, index) => {
    if (sample.collected_at) {
      timeline.push({
        id: `sample-collected-${sample.id || index}`,
        type: 'SAMPLE_COLLECTED',
        at: sample.collected_at,
        label: `Sample ${sample.display_id || index + 1} collected`,
      });
    }
    if (sample.received_at) {
      timeline.push({
        id: `sample-received-${sample.id || index}`,
        type: 'SAMPLE_RECEIVED',
        at: sample.received_at,
        label: `Sample ${sample.display_id || index + 1} received`,
      });
    }
  });

  const results = [];
  (record?.items || []).forEach((item) => {
    (item?.results || []).forEach((result) => {
      const mapped = mapLabResultRecord({
        ...result,
        lab_order_item: item,
      });
      if (mapped) {
        results.push(mapped);
        if (mapped.reported_at) {
          timeline.push({
            id: `result-${mapped.id || `${item.id}-reported`}`,
            type: 'RESULT_REPORTED',
            at: mapped.reported_at,
            label: `Result reported for ${mapped.test_display_name || mapped.lab_test_id || 'test item'}`,
          });
        }
      }
    });
  });

  timeline.sort((a, b) => {
    const left = Date.parse(a.at || '');
    const right = Date.parse(b.at || '');
    if (!Number.isFinite(left) && !Number.isFinite(right)) return 0;
    if (!Number.isFinite(left)) return 1;
    if (!Number.isFinite(right)) return -1;
    return left - right;
  });

  return {
    order,
    results,
    timeline,
    next_actions: {
      can_collect: ['ORDERED', 'COLLECTED'].includes(toText(order.status).toUpperCase()),
      can_receive_sample: order.samples.some((sample) => ['PENDING', 'COLLECTED'].includes(toText(sample.status).toUpperCase())),
      can_release_result: order.items.some((item) => ['ORDERED', 'COLLECTED', 'IN_PROCESS'].includes(toText(item.status).toUpperCase())),
      can_reverse_workflow: Boolean(resolveLatestReverseWorkflowTarget(record)),
    },
  };
};

module.exports = {
  toPublicIdentifier,
  toIsoDateTime,
  mapLabReferenceRangeRecord,
  mapLabUnitOptionRecord,
  mapLabResultOptionRecord,
  mapLabTestRecord,
  mapLabPanelItemRecord,
  mapLabPanelRecord,
  mapLabOrderRecord,
  mapLabOrderItemRecord,
  mapLabSampleRecord,
  mapLabResultRecord,
  mapLabQcLogRecord,
  mapLabOrderWorkflowRecord,
};
