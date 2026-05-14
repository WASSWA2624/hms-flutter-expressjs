const mortuaryWorkspaceRepository = require('@repositories/mortuary-workspace/mortuary-workspace.repository');
const { resolvePublicIdentifier, resolveIdentifierForFilter } = require('@lib/billing/identifiers');

const DEFAULT_PANEL = 'overview';
const DEFAULT_RESOURCE_BY_PANEL = Object.freeze({
  overview: 'mortuary-cases',
  intake: 'mortuary-cases',
  storage: 'mortuary-storage-assignments',
  custody: 'mortuary-custody-events',
  release: 'mortuary-release-authorisations',
  reporting: 'mortuary-post-mortem-requests',
});

const PANEL_DEFINITIONS = Object.freeze([
  { id: 'overview', label_key: 'mortuary.panels.overview', default_resource: 'mortuary-cases' },
  { id: 'intake', label_key: 'mortuary.panels.intake', default_resource: 'mortuary-cases' },
  { id: 'storage', label_key: 'mortuary.panels.storage', default_resource: 'mortuary-storage-assignments' },
  { id: 'custody', label_key: 'mortuary.panels.custody', default_resource: 'mortuary-custody-events' },
  { id: 'release', label_key: 'mortuary.panels.release', default_resource: 'mortuary-release-authorisations' },
  { id: 'reporting', label_key: 'mortuary.panels.reporting', default_resource: 'mortuary-post-mortem-requests' },
]);

const QUEUE_DEFINITIONS = Object.freeze([
  { id: 'IDENTIFICATION_PENDING', label_key: 'mortuary.queues.identificationPending', panel: 'intake', resource: 'mortuary-cases' },
  { id: 'STORAGE_EXCEPTIONS', label_key: 'mortuary.queues.storageExceptions', panel: 'storage', resource: 'mortuary-storage-assignments' },
  { id: 'RELEASE_READY', label_key: 'mortuary.queues.releaseReady', panel: 'release', resource: 'mortuary-release-authorisations' },
  { id: 'UNSETTLED_BILLING', label_key: 'mortuary.queues.unsettledBilling', panel: 'release', resource: 'mortuary-billable-events' },
  { id: 'POST_MORTEM_PENDING', label_key: 'mortuary.queues.postMortemPending', panel: 'reporting', resource: 'mortuary-post-mortem-requests' },
]);

const CASE_STATUS_OPTIONS = Object.freeze([
  'RECEIVED',
  'IDENTIFICATION_PENDING',
  'IN_STORAGE',
  'POST_MORTEM_PENDING',
  'READY_FOR_RELEASE',
  'RELEASED',
  'CLOSED',
  'CANCELLED',
]);

const IDENTIFICATION_STATUS_OPTIONS = Object.freeze([
  'UNVERIFIED',
  'PARTIAL',
  'VERIFIED',
]);

const STORAGE_SLOT_STATUS_OPTIONS = Object.freeze([
  'AVAILABLE',
  'OCCUPIED',
  'HELD',
  'OUT_OF_SERVICE',
  'CLEANING',
]);

const POST_MORTEM_STATUS_OPTIONS = Object.freeze([
  'REQUESTED',
  'APPROVED',
  'SCHEDULED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
]);

const RELEASE_STATUS_OPTIONS = Object.freeze([
  'DRAFT',
  'APPROVED',
  'RELEASED',
  'CANCELLED',
]);

const SORT_FIELDS_BY_RESOURCE = Object.freeze({
  'mortuary-cases': new Set(['received_at', 'updated_at', 'created_at', 'release_ready_at', 'released_at']),
  'mortuary-storage-units': new Set(['name', 'updated_at', 'created_at', 'capacity']),
  'mortuary-storage-slots': new Set(['slot_code', 'updated_at', 'created_at', 'status']),
  'mortuary-storage-assignments': new Set(['assigned_at', 'updated_at', 'created_at', 'ended_at']),
  'mortuary-custody-events': new Set(['event_at', 'updated_at', 'created_at']),
  'mortuary-viewings': new Set(['scheduled_at', 'updated_at', 'created_at', 'completed_at']),
  'mortuary-post-mortem-requests': new Set(['scheduled_at', 'updated_at', 'created_at', 'completed_at']),
  'mortuary-release-authorisations': new Set(['approved_at', 'released_at', 'updated_at', 'created_at']),
  'mortuary-billable-events': new Set(['charged_at', 'settled_at', 'updated_at', 'created_at']),
});

const DEFAULT_SORT_BY_RESOURCE = Object.freeze({
  'mortuary-cases': 'received_at',
  'mortuary-storage-units': 'name',
  'mortuary-storage-slots': 'slot_code',
  'mortuary-storage-assignments': 'assigned_at',
  'mortuary-custody-events': 'event_at',
  'mortuary-viewings': 'scheduled_at',
  'mortuary-post-mortem-requests': 'created_at',
  'mortuary-release-authorisations': 'created_at',
  'mortuary-billable-events': 'charged_at',
});

const normalizeString = (value) => String(value || '').trim();
const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: page * limit < total,
  hasPreviousPage: page > 1,
});

const buildWorkspacePath = (params = {}) => {
  const query = new URLSearchParams();
  [
    'panel',
    'resource',
    'queue',
    'search',
    'status',
    'identificationStatus',
    'facilityId',
    'storageUnitId',
    'storageSlotId',
    'datePreset',
    'id',
    'action',
  ].forEach((key) => {
    const value = normalizeString(params[key]);
    if (value) query.set(key, value);
  });

  const serialized = query.toString();
  return serialized ? `/mortuary?${serialized}` : '/mortuary';
};

const buildOrderBy = (resource, sortBy, order) => {
  const allowedFields = SORT_FIELDS_BY_RESOURCE[resource] || SORT_FIELDS_BY_RESOURCE['mortuary-cases'];
  const defaultField = DEFAULT_SORT_BY_RESOURCE[resource] || DEFAULT_SORT_BY_RESOURCE['mortuary-cases'];
  const requestedField = normalizeString(sortBy);
  const field = allowedFields.has(requestedField) ? requestedField : defaultField;
  return { [field]: order === 'asc' ? 'asc' : 'desc' };
};

const mapLookupOption = (record, label, subtitle = null, meta = null) => ({
  id: safePublicId(record?.human_friendly_id, record?.id),
  label,
  subtitle,
  meta,
});

const mapEnumOptions = (values) =>
  values.map((value) => ({ id: value, label: value, subtitle: null, meta: null }));

const mapSummaryCards = (summary = {}) => [
  { id: 'total_cases', label_key: 'mortuary.summary.totalCases', value: Number(summary.total_cases || 0) },
  { id: 'identification_pending', label_key: 'mortuary.summary.identificationPending', value: Number(summary.identification_pending || 0) },
  { id: 'in_storage', label_key: 'mortuary.summary.inStorage', value: Number(summary.in_storage || 0) },
  { id: 'release_ready', label_key: 'mortuary.summary.releaseReady', value: Number(summary.release_ready || 0) },
  { id: 'unsettled_billing', label_key: 'mortuary.summary.unsettledBilling', value: Number(summary.unsettled_billing || 0) },
];

const mapQueueSummaries = (queueCounts = {}) =>
  QUEUE_DEFINITIONS.map((definition) => ({
    queue: definition.id,
    label_key: definition.label_key,
    count: Number(queueCounts[definition.id] || 0),
    panel: definition.panel,
    resource: definition.resource,
    target_path: buildWorkspacePath({
      panel: definition.panel,
      resource: definition.resource,
      queue: definition.id,
    }),
  }));

const mapPanelSummaries = (summary = {}, queueCounts = {}) =>
  PANEL_DEFINITIONS.map((panel) => {
    let count = 0;
    if (panel.id === 'overview') count = Number(summary.total_cases || 0);
    if (panel.id === 'intake') count = Number(queueCounts.IDENTIFICATION_PENDING || 0);
    if (panel.id === 'storage') count = Number(queueCounts.STORAGE_EXCEPTIONS || 0);
    if (panel.id === 'custody') count = Number(summary.in_storage || 0);
    if (panel.id === 'release') {
      count =
        Number(queueCounts.RELEASE_READY || 0) +
        Number(queueCounts.UNSETTLED_BILLING || 0);
    }
    if (panel.id === 'reporting') count = Number(queueCounts.POST_MORTEM_PENDING || 0);

    return {
      id: panel.id,
      label_key: panel.label_key,
      default_resource: panel.default_resource,
      count,
      target_path: buildWorkspacePath({
        panel: panel.id,
        resource: panel.default_resource,
      }),
    };
  });

const mapSpotlight = (queueCounts = {}) =>
  mapQueueSummaries(queueCounts)
    .filter((entry) => entry.count > 0)
    .sort((left, right) => right.count - left.count)
    .slice(0, 5);

const mapCaseSummary = (mortuaryCase = {}) => {
  const publicId = safePublicId(mortuaryCase.human_friendly_id, mortuaryCase.id);
  return {
    id: publicId,
    human_friendly_id: publicId,
    status: mortuaryCase.status || null,
    identification_status: mortuaryCase.identification_status || null,
    received_at: mortuaryCase.received_at || null,
    release_ready_at: mortuaryCase.release_ready_at || null,
    released_at: mortuaryCase.released_at || null,
    billing_status: mortuaryCase.billing_status || null,
    deceased_profile_id: safePublicId(
      mortuaryCase.deceased_profile?.human_friendly_id,
      mortuaryCase.deceased_profile?.id
    ),
    deceased_profile_label: mortuaryCase.deceased_profile?.display_name || null,
  };
};

const mapStorageAssignment = (assignment = null) => {
  if (!assignment) return null;
  const unitPublicId = safePublicId(
    assignment.storage_unit?.human_friendly_id,
    assignment.storage_unit?.id
  );
  const slotPublicId = safePublicId(
    assignment.storage_slot?.human_friendly_id,
    assignment.storage_slot?.id
  );

  return {
    id: safePublicId(assignment.human_friendly_id, assignment.id),
    human_friendly_id: safePublicId(assignment.human_friendly_id, assignment.id),
    assignment_status: assignment.assignment_status || null,
    assigned_at: assignment.assigned_at || null,
    ended_at: assignment.ended_at || null,
    reason: assignment.reason || null,
    storage_unit_id: unitPublicId,
    storage_unit_label: assignment.storage_unit?.name || null,
    storage_slot_id: slotPublicId,
    storage_slot_label:
      assignment.storage_slot?.label || assignment.storage_slot?.slot_code || null,
    storage_slot_status: assignment.storage_slot?.status || null,
  };
};

const mapTimelineEvent = (event = {}) => ({
  id: safePublicId(event.human_friendly_id, event.id),
  human_friendly_id: safePublicId(event.human_friendly_id, event.id),
  event_type: event.event_type || null,
  event_at: event.event_at || null,
  occurred_at: event.event_at || null,
  actor_name: event.actor_name || null,
  actor_role: event.actor_role || null,
  location_label: event.location_label || null,
  reason: event.reason || null,
  notes: event.notes || null,
  created_at: event.created_at || null,
  updated_at: event.updated_at || null,
});

const mapCaseItem = (resource, item = {}) => {
  const publicId = safePublicId(item.human_friendly_id, item.id);
  const patientLabel = [item.patient?.first_name, item.patient?.last_name]
    .filter(Boolean)
    .join(' ');
  const activeStorageAssignment = mapStorageAssignment(item.storage_assignments?.[0]);
  const latestRelease = item.release_authorisations?.[0] || null;
  const latestBillableEvent = item.billable_events?.[0] || null;

  return {
    id: publicId,
    human_friendly_id: publicId,
    resource,
    title: item.deceased_profile?.display_name || publicId,
    subtitle: item.source_workflow || item.received_from || item.status || null,
    status: item.status || null,
    identification_status: item.identification_status || null,
    billing_status: item.billing_status || null,
    billing_reference_id: latestBillableEvent?.billing_reference_id || null,
    release_status: latestRelease?.status || null,
    facility_id: safePublicId(item.facility?.human_friendly_id, item.facility?.id),
    facility_label: item.facility?.name || null,
    patient_id: safePublicId(item.patient?.human_friendly_id, item.patient?.id),
    patient_label: patientLabel || null,
    deceased_profile_id: safePublicId(
      item.deceased_profile?.human_friendly_id,
      item.deceased_profile?.id
    ),
    deceased_profile_label: item.deceased_profile?.display_name || null,
    source_workflow: item.source_workflow || null,
    source_department: item.source_department || null,
    source_reference_id: item.source_reference_id || null,
    received_from: item.received_from || null,
    received_at: item.received_at || null,
    release_ready_at: item.release_ready_at || null,
    released_at: item.released_at || null,
    closed_at: item.closed_at || null,
    active_storage_assignment: activeStorageAssignment,
    storage_unit_id: activeStorageAssignment?.storage_unit_id || null,
    storage_unit_label: activeStorageAssignment?.storage_unit_label || null,
    storage_slot_id: activeStorageAssignment?.storage_slot_id || null,
    storage_slot_label: activeStorageAssignment?.storage_slot_label || null,
    custody_events: (item.custody_events || []).map(mapTimelineEvent),
    viewings: (item.viewings || []).map((entry) => ({
      id: safePublicId(entry.human_friendly_id, entry.id),
      human_friendly_id: safePublicId(entry.human_friendly_id, entry.id),
      scheduled_at: entry.scheduled_at || null,
      status: entry.status || null,
      authorised_by_name: entry.authorised_by_name || null,
      attendee_summary: entry.attendee_summary || null,
      completed_at: entry.completed_at || null,
    })),
    post_mortem_requests: (item.post_mortem_requests || []).map((entry) => ({
      id: safePublicId(entry.human_friendly_id, entry.id),
      human_friendly_id: safePublicId(entry.human_friendly_id, entry.id),
      requested_by_name: entry.requested_by_name || null,
      request_reason: entry.request_reason || null,
      status: entry.status || null,
      diagnostics_reference_id: entry.diagnostics_reference_id || null,
      scheduled_at: entry.scheduled_at || null,
      completed_at: entry.completed_at || null,
      report_received_at: entry.report_received_at || null,
    })),
    release_authorisations: (item.release_authorisations || []).map((entry) => ({
      id: safePublicId(entry.human_friendly_id, entry.id),
      human_friendly_id: safePublicId(entry.human_friendly_id, entry.id),
      recipient_name: entry.recipient_name || null,
      recipient_relationship: entry.recipient_relationship || null,
      verification_reference: entry.verification_reference || null,
      funeral_service_name: entry.funeral_service_name || null,
      release_method: entry.release_method || null,
      status: entry.status || null,
      approved_by_name: entry.approved_by_name || null,
      approved_at: entry.approved_at || null,
      released_at: entry.released_at || null,
    })),
    billable_events: (item.billable_events || []).map((entry) => ({
      id: safePublicId(entry.human_friendly_id, entry.id),
      human_friendly_id: safePublicId(entry.human_friendly_id, entry.id),
      event_type: entry.event_type || null,
      description: entry.description || null,
      amount: entry.amount == null ? null : String(entry.amount),
      currency: entry.currency || null,
      status: entry.status || null,
      billing_reference_id: entry.billing_reference_id || null,
      charged_at: entry.charged_at || null,
      settled_at: entry.settled_at || null,
    })),
    target_path: buildWorkspacePath({
      panel: 'overview',
      resource,
      id: publicId,
      action: 'view',
    }),
    timeline_at: item.updated_at || item.received_at || item.created_at || null,
    created_at: item.created_at || null,
    updated_at: item.updated_at || null,
  };
};

const mapRelatedCaseResourceItem = (resource, item = {}) => {
  const publicId = safePublicId(item.human_friendly_id, item.id);
  const caseSummary = mapCaseSummary(item.mortuary_case || {});
  const storageAssignment = mapStorageAssignment(item);

  const base = {
    id: publicId,
    human_friendly_id: publicId,
    resource,
    facility_id: safePublicId(item.facility?.human_friendly_id, item.facility?.id),
    facility_label: item.facility?.name || null,
    mortuary_case: caseSummary,
    mortuary_case_id: caseSummary.id || null,
    case_status: caseSummary.status || null,
    identification_status: caseSummary.identification_status || null,
    title: caseSummary.deceased_profile_label || caseSummary.human_friendly_id || publicId,
    target_path: buildWorkspacePath({
      resource,
      id: publicId,
      action: 'view',
    }),
    created_at: item.created_at || null,
    updated_at: item.updated_at || null,
  };

  if (resource === 'mortuary-storage-assignments') {
    return {
      ...base,
      ...storageAssignment,
      status: item.assignment_status || null,
      subtitle: storageAssignment?.storage_slot_label || storageAssignment?.storage_unit_label || null,
      timeline_at: item.assigned_at || item.updated_at || item.created_at || null,
    };
  }

  if (resource === 'mortuary-custody-events') {
    return {
      ...base,
      ...mapTimelineEvent(item),
      status: item.event_type || null,
      subtitle: item.location_label || item.actor_name || null,
      timeline_at: item.event_at || item.updated_at || item.created_at || null,
    };
  }

  if (resource === 'mortuary-viewings') {
    return {
      ...base,
      status: item.status || null,
      subtitle: item.authorised_by_name || item.attendee_summary || null,
      scheduled_at: item.scheduled_at || null,
      authorised_by_name: item.authorised_by_name || null,
      attendee_summary: item.attendee_summary || null,
      completed_at: item.completed_at || null,
      timeline_at: item.scheduled_at || item.updated_at || item.created_at || null,
    };
  }

  if (resource === 'mortuary-post-mortem-requests') {
    return {
      ...base,
      status: item.status || null,
      subtitle: item.diagnostics_reference_id || item.requested_by_name || null,
      requested_by_name: item.requested_by_name || null,
      request_reason: item.request_reason || null,
      diagnostics_reference_id: item.diagnostics_reference_id || null,
      scheduled_at: item.scheduled_at || null,
      completed_at: item.completed_at || null,
      report_received_at: item.report_received_at || null,
      timeline_at: item.scheduled_at || item.updated_at || item.created_at || null,
    };
  }

  if (resource === 'mortuary-release-authorisations') {
    return {
      ...base,
      status: item.status || null,
      release_status: item.status || null,
      subtitle: item.recipient_name || item.verification_reference || null,
      recipient_name: item.recipient_name || null,
      recipient_relationship: item.recipient_relationship || null,
      verification_reference: item.verification_reference || null,
      funeral_service_name: item.funeral_service_name || null,
      release_method: item.release_method || null,
      approved_by_name: item.approved_by_name || null,
      approved_at: item.approved_at || null,
      released_at: item.released_at || null,
      timeline_at: item.released_at || item.approved_at || item.updated_at || item.created_at || null,
    };
  }

  return {
    ...base,
    status: item.status || null,
    subtitle: item.billing_reference_id || item.event_type || null,
    event_type: item.event_type || null,
    description: item.description || null,
    amount: item.amount == null ? null : String(item.amount),
    currency: item.currency || null,
    billing_reference_id: item.billing_reference_id || null,
    charged_at: item.charged_at || null,
    settled_at: item.settled_at || null,
    timeline_at: item.charged_at || item.updated_at || item.created_at || null,
  };
};

const mapStorageUnitItem = (resource, item = {}) => ({
  id: safePublicId(item.human_friendly_id, item.id),
  human_friendly_id: safePublicId(item.human_friendly_id, item.id),
  resource,
  title: item.name || safePublicId(item.human_friendly_id, item.id),
  subtitle: item.location_label || item.unit_type || null,
  status: item.status || null,
  facility_id: safePublicId(item.facility?.human_friendly_id, item.facility?.id),
  facility_label: item.facility?.name || null,
  unit_type: item.unit_type || null,
  capacity: item.capacity || 0,
  slot_count: item._count?.slots || 0,
  assignment_count: item._count?.assignments || 0,
  timeline_at: item.updated_at || item.created_at || null,
  target_path: buildWorkspacePath({ panel: 'storage', resource, id: safePublicId(item.human_friendly_id, item.id), action: 'view' }),
  created_at: item.created_at || null,
  updated_at: item.updated_at || null,
});

const mapStorageSlotItem = (resource, item = {}) => {
  const activeAssignment = mapStorageAssignment(item.assignments?.[0]);
  return {
    id: safePublicId(item.human_friendly_id, item.id),
    human_friendly_id: safePublicId(item.human_friendly_id, item.id),
    resource,
    title: item.label || item.slot_code || safePublicId(item.human_friendly_id, item.id),
    subtitle: item.storage_unit?.name || item.temperature_zone || null,
    status: item.status || null,
    facility_id: safePublicId(item.facility?.human_friendly_id, item.facility?.id),
    facility_label: item.facility?.name || null,
    storage_unit_id: safePublicId(item.storage_unit?.human_friendly_id, item.storage_unit?.id),
    storage_unit_label: item.storage_unit?.name || null,
    storage_slot_id: safePublicId(item.human_friendly_id, item.id),
    storage_slot_label: item.label || item.slot_code || null,
    slot_code: item.slot_code || null,
    temperature_zone: item.temperature_zone || null,
    is_active: Boolean(item.is_active),
    active_storage_assignment: activeAssignment,
    mortuary_case: mapCaseSummary(item.assignments?.[0]?.mortuary_case || {}),
    timeline_at: item.updated_at || item.created_at || null,
    target_path: buildWorkspacePath({ panel: 'storage', resource, id: safePublicId(item.human_friendly_id, item.id), action: 'view' }),
    created_at: item.created_at || null,
    updated_at: item.updated_at || null,
  };
};

const mapItem = (resource, item) => {
  if (resource === 'mortuary-cases') return mapCaseItem(resource, item);
  if (resource === 'mortuary-storage-units') return mapStorageUnitItem(resource, item);
  if (resource === 'mortuary-storage-slots') return mapStorageSlotItem(resource, item);
  return mapRelatedCaseResourceItem(resource, item);
};

const resolveScopedFilters = async (filters = {}, user = {}) => {
  const tenantId = user?.tenant_id || user?.tenantId || null;
  const tenantWhere = tenantId ? { tenant_id: tenantId } : {};
  const facilityValue = filters.facility_id || user?.facility_id || user?.facilityId;
  const facilityId = await resolveIdentifierForFilter({
    value: facilityValue,
    model: 'facility',
    where: tenantWhere,
  });
  const facilityWhere = {
    ...tenantWhere,
    ...(facilityId ? { facility_id: facilityId } : {}),
  };

  const storageUnitId = await resolveIdentifierForFilter({
    value: filters.storage_unit_id,
    model: 'mortuary_storage_unit',
    where: facilityWhere,
  });
  const storageSlotId = await resolveIdentifierForFilter({
    value: filters.storage_slot_id,
    model: 'mortuary_storage_slot',
    where: {
      ...facilityWhere,
      ...(storageUnitId ? { storage_unit_id: storageUnitId } : {}),
    },
  });

  return {
    tenantId,
    facilityId,
    storageUnitId,
    storageSlotId,
    status: normalizeString(filters.status) || undefined,
    identificationStatus: normalizeString(filters.identification_status) || undefined,
    search: normalizeString(filters.search) || undefined,
    queue: normalizeString(filters.queue) || undefined,
    datePreset: normalizeString(filters.date_preset) || undefined,
    id: normalizeString(filters.id) || undefined,
    action: normalizeString(filters.action) || undefined,
  };
};

const getWorkspace = async (filters = {}, page = 1, limit = 20, sortBy, order = 'desc', user = {}) => {
  const panel = normalizeString(filters.panel) || DEFAULT_PANEL;
  const resource =
    normalizeString(filters.resource) ||
    DEFAULT_RESOURCE_BY_PANEL[panel] ||
    DEFAULT_RESOURCE_BY_PANEL[DEFAULT_PANEL];
  const scopedFilters = await resolveScopedFilters(filters, user);
  const skip = (page - 1) * limit;
  const orderBy = buildOrderBy(resource, sortBy, order);

  const [summary, queueCounts, listResult, lookups] = await Promise.all([
    mortuaryWorkspaceRepository.findSummary(scopedFilters),
    mortuaryWorkspaceRepository.findQueueCounts(scopedFilters),
    mortuaryWorkspaceRepository.findItems({
      resource,
      filters: scopedFilters,
      skip,
      take: limit,
      orderBy,
    }),
    mortuaryWorkspaceRepository.findLookups(scopedFilters),
  ]);

  return {
    summary: mapSummaryCards(summary),
    queue_summaries: mapQueueSummaries(queueCounts),
    panel_summaries: mapPanelSummaries(summary, queueCounts),
    filters: {
      panel,
      resource,
      queue: normalizeString(filters.queue) || null,
      search: normalizeString(filters.search) || '',
      status: normalizeString(filters.status) || null,
      identification_status: normalizeString(filters.identification_status) || null,
      facility_id: safePublicId(undefined, scopedFilters.facilityId),
      storage_unit_id: safePublicId(undefined, scopedFilters.storageUnitId),
      storage_slot_id: safePublicId(undefined, scopedFilters.storageSlotId),
      date_preset: normalizeString(filters.date_preset) || null,
      id: normalizeString(filters.id) || null,
      action: normalizeString(filters.action) || null,
    },
    lookups: mapLookups(lookups),
    items: (listResult.items || []).map((item) => mapItem(resource, item)),
    pagination: buildPagination(page, limit, Number(listResult.total || 0)),
    spotlight: mapSpotlight(queueCounts),
    last_updated_at: new Date(),
  };
};

const mapLookups = (lookups = {}) => ({
  facilities: (lookups.facilities || []).map((entry) =>
    mapLookupOption(entry, entry.name, entry.facility_type || null, {
      facility_type: entry.facility_type || null,
    })
  ),
  storage_units: (lookups.storageUnits || []).map((entry) =>
    mapLookupOption(entry, entry.name, entry.location_label || entry.unit_type || null, {
      unit_type: entry.unit_type || null,
      status: entry.status || null,
    })
  ),
  storage_slots: (lookups.storageSlots || []).map((entry) =>
    mapLookupOption(
      entry,
      entry.label || entry.slot_code,
      entry.storage_unit?.name || entry.status || null,
      {
        status: entry.status || null,
        temperature_zone: entry.temperature_zone || null,
        storage_unit_id: safePublicId(
          entry.storage_unit?.human_friendly_id,
          entry.storage_unit?.id
        ),
      }
    )
  ),
  deceased_profiles: (lookups.deceasedProfiles || []).map((entry) =>
    mapLookupOption(
      entry,
      entry.display_name,
      entry.external_reference || entry.date_of_death || null,
      { date_of_death: entry.date_of_death || null }
    )
  ),
  patients: (lookups.patients || []).map((entry) =>
    mapLookupOption(
      entry,
      [entry.first_name, entry.last_name].filter(Boolean).join(' '),
      safePublicId(entry.human_friendly_id, entry.id),
      null
    )
  ),
  source_workflows: (lookups.sourceWorkflows || [])
    .map((entry) => normalizeString(entry.source_workflow))
    .filter(Boolean)
    .map((entry) => ({ id: entry, label: entry, subtitle: null, meta: null })),
  statuses: mapEnumOptions(CASE_STATUS_OPTIONS),
  identification_statuses: mapEnumOptions(IDENTIFICATION_STATUS_OPTIONS),
  storage_slot_statuses: mapEnumOptions(STORAGE_SLOT_STATUS_OPTIONS),
  post_mortem_statuses: mapEnumOptions(POST_MORTEM_STATUS_OPTIONS),
  release_statuses: mapEnumOptions(RELEASE_STATUS_OPTIONS),
  queues: QUEUE_DEFINITIONS.map((entry) => ({
    id: entry.id,
    label: entry.id,
    subtitle: entry.panel,
    meta: { resource: entry.resource },
  })),
});

const getLookups = async (filters = {}, user = {}) => {
  const scopedFilters = await resolveScopedFilters(filters, user);
  const lookups = await mortuaryWorkspaceRepository.findLookups(scopedFilters);
  return mapLookups(lookups);
};

module.exports = {
  getWorkspace,
  getLookups,
};
