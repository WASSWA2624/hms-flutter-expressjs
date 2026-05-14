const biomedicalWorkspaceRepository = require('@repositories/biomedical-workspace/biomedical-workspace.repository');
const prisma = require('@prisma/client');
const { resolvePublicIdentifier, resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  emitToUser,
  emitToUsers,
  BIOMEDICAL_EVENTS,
  NOTIFICATION_EVENTS,
} = require('@lib/websocket');

const DEFAULT_PANEL = 'overview';
const DEFAULT_RESOURCE_BY_PANEL = Object.freeze({
  overview: 'equipment-work-orders',
  registry: 'equipment-registries',
  preventive: 'equipment-maintenance-plans',
  'work-orders': 'equipment-work-orders',
  compliance: 'equipment-calibration-logs',
  support: 'equipment-service-providers',
  analytics: 'equipment-utilization-snapshots',
});

const PANEL_DEFINITIONS = Object.freeze([
  { id: 'overview', label_key: 'biomedical.workspace.panels.overview', default_resource: 'equipment-work-orders' },
  { id: 'registry', label_key: 'biomedical.workspace.panels.registry', default_resource: 'equipment-registries' },
  { id: 'preventive', label_key: 'biomedical.workspace.panels.preventive', default_resource: 'equipment-maintenance-plans' },
  { id: 'work-orders', label_key: 'biomedical.workspace.panels.workOrders', default_resource: 'equipment-work-orders' },
  { id: 'compliance', label_key: 'biomedical.workspace.panels.compliance', default_resource: 'equipment-calibration-logs' },
  { id: 'support', label_key: 'biomedical.workspace.panels.support', default_resource: 'equipment-service-providers' },
  { id: 'analytics', label_key: 'biomedical.workspace.panels.analytics', default_resource: 'equipment-utilization-snapshots' },
]);

const QUEUE_DEFINITIONS = Object.freeze([
  { id: 'OVERDUE_PM', label_key: 'biomedical.workspace.queues.OVERDUE_PM', panel: 'preventive', resource: 'equipment-maintenance-plans' },
  { id: 'OPEN_WORK_ORDERS', label_key: 'biomedical.workspace.queues.OPEN_WORK_ORDERS', panel: 'work-orders', resource: 'equipment-work-orders' },
  { id: 'CRITICAL_DOWNTIME', label_key: 'biomedical.workspace.queues.CRITICAL_DOWNTIME', panel: 'compliance', resource: 'equipment-downtime-logs' },
  { id: 'RECALL_ACTIONS', label_key: 'biomedical.workspace.queues.RECALL_ACTIONS', panel: 'compliance', resource: 'equipment-recall-notices' },
  { id: 'RETURN_TO_SERVICE', label_key: 'biomedical.workspace.queues.RETURN_TO_SERVICE', panel: 'work-orders', resource: 'equipment-work-orders' },
]);

const STATUS_OPTIONS = Object.freeze(['OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'ACTIVE', 'INACTIVE', 'RETURNED_TO_SERVICE']);
const PRIORITY_OPTIONS = Object.freeze(['LOW', 'NORMAL', 'HIGH', 'CRITICAL']);

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
  ['panel', 'resource', 'queue', 'status', 'priority', 'facilityId', 'equipmentId', 'engineerId', 'id', 'action'].forEach((key) => {
    const value = normalizeString(params[key]);
    if (value) query.set(key, value);
  });
  const serialized = query.toString();
  return serialized ? `/biomedical?${serialized}` : '/biomedical';
};

const toSafeNotificationPayload = (notification, targetPath) => ({
  id: notification.human_friendly_id || null,
  tenant_id: null,
  user_id: null,
  notification_type: notification.notification_type,
  priority: notification.priority,
  title: notification.title,
  message: notification.message,
  read_at: notification.read_at || null,
  created_at: notification.created_at,
  updated_at: notification.updated_at,
  target_path: targetPath || null,
});

const buildFaultNotificationContent = ({
  equipmentLabel,
  severity,
  priority,
  patientSafetyRisk,
  isPlaceholderEquipment = false,
}) => {
  const normalizedEquipmentLabel = normalizeString(equipmentLabel) || 'equipment';
  const normalizedSeverity = normalizeString(severity) || 'HIGH';
  const normalizedPriority = normalizeString(priority) || 'NORMAL';
  const title = patientSafetyRisk || normalizedSeverity === 'CRITICAL'
    ? 'Critical equipment issue reported'
    : 'Equipment issue reported';
  const messageParts = [
    `${normalizedEquipmentLabel} needs biomedical attention.`,
    `Severity: ${normalizedSeverity}.`,
    `Priority: ${normalizedPriority}.`,
    isPlaceholderEquipment
      ? 'A temporary inventory record was created because the equipment was not yet registered.'
      : null,
  ].filter(Boolean);

  return {
    title,
    message: messageParts.join(' '),
  };
};

const createAndEmitFaultNotifications = async ({
  tenantId,
  recipientUserIds = [],
  targetPath,
  contextPublicId = null,
  equipment,
  severity,
  priority,
  patientSafetyRisk,
  isPlaceholderEquipment = false,
}) => {
  if (!Array.isArray(recipientUserIds) || recipientUserIds.length === 0) {
    return [];
  }

  if (!prisma?.notification?.create) {
    return [];
  }

  const { title, message } = buildFaultNotificationContent({
    equipmentLabel: equipment?.equipment_name,
    severity,
    priority,
    patientSafetyRisk,
    isPlaceholderEquipment,
  });
  const notificationPriority =
    patientSafetyRisk || severity === 'CRITICAL'
      ? 'URGENT'
      : severity === 'HIGH' || priority === 'CRITICAL'
        ? 'HIGH'
        : 'MEDIUM';
  const createdNotifications = [];

  for (const userId of recipientUserIds) {
    try {
      const notification = await prisma.notification.create({
        data: {
          tenant_id: tenantId,
          user_id: userId,
          notification_type: 'SYSTEM',
          priority: notificationPriority,
          title,
          message,
          target_path: targetPath || null,
          context_type: 'equipment_work_order',
          context_public_id: normalizeString(contextPublicId) || null,
        },
      });
      createdNotifications.push(notification);
    } catch (_error) {
      // Notification creation should not block fault reporting.
    }
  }

  if (
    createdNotifications.length > 0 &&
    prisma?.notification_delivery?.createMany
  ) {
    try {
      await prisma.notification_delivery.createMany({
        data: createdNotifications.map((notification) => ({
          notification_id: notification.id,
          channel: 'IN_APP',
          status: 'SENT',
          sent_at: new Date(),
        })),
      });
    } catch (_error) {
      // Delivery metadata should stay non-blocking.
    }
  }

  createdNotifications.forEach((notification) => {
    emitToUser(notification.user_id, NOTIFICATION_EVENTS.NOTIFICATION_CREATED, {
      notification: toSafeNotificationPayload(notification, targetPath),
      target_path: targetPath || null,
    });
  });

  return createdNotifications;
};

const mapLookupOption = (record, label, subtitle = null, meta = null) => ({
  id: safePublicId(record?.human_friendly_id, record?.id),
  label,
  subtitle,
  meta,
});

const mapSummaryCards = (summary = {}) => [
  { id: 'total_equipment', label_key: 'biomedical.workspace.summary.totalEquipment', value: Number(summary.total_equipment || 0) },
  { id: 'overdue_pm', label_key: 'biomedical.workspace.summary.overduePm', value: Number(summary.overdue_pm || 0) },
  { id: 'open_work_orders', label_key: 'biomedical.workspace.summary.openWorkOrders', value: Number(summary.open_work_orders || 0) },
  { id: 'critical_downtime', label_key: 'biomedical.workspace.summary.criticalDowntime', value: Number(summary.critical_downtime || 0) },
  { id: 'active_recalls', label_key: 'biomedical.workspace.summary.activeRecalls', value: Number(summary.active_recalls || 0) },
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
    if (panel.id === 'overview') count = Number(summary.open_work_orders || 0) + Number(summary.overdue_pm || 0);
    if (panel.id === 'registry') count = Number(summary.total_equipment || 0);
    if (panel.id === 'preventive') count = Number(queueCounts.OVERDUE_PM || 0);
    if (panel.id === 'work-orders') count = Number(queueCounts.OPEN_WORK_ORDERS || 0) + Number(queueCounts.RETURN_TO_SERVICE || 0);
    if (panel.id === 'compliance') count = Number(queueCounts.CRITICAL_DOWNTIME || 0) + Number(queueCounts.RECALL_ACTIONS || 0);
    if (panel.id === 'support') count = Number(summary.active_recalls || 0);
    if (panel.id === 'analytics') count = Number(summary.total_equipment || 0);

    return {
      id: panel.id,
      label_key: panel.label_key,
      default_resource: panel.default_resource,
      count,
      target_path: buildWorkspacePath({ panel: panel.id, resource: panel.default_resource }),
    };
  });

const mapSpotlight = (queueCounts = {}) =>
  mapQueueSummaries(queueCounts)
    .filter((entry) => entry.count > 0)
    .sort((left, right) => right.count - left.count)
    .slice(0, 5);

const mapItem = (resource, item, maps = {}) => {
  const facilityLabel = item?.facility_id ? maps.facilityMap?.get(item.facility_id)?.label || null : null;
  const facilityId = item?.facility_id ? maps.facilityMap?.get(item.facility_id)?.id || null : null;
  const engineer = item?.assigned_engineer_user_id ? maps.engineerMap?.get(item.assigned_engineer_user_id) : null;

  if (resource === 'equipment-registries') {
    return {
      id: safePublicId(item?.human_friendly_id, item?.id),
      human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
      resource,
      title: item?.equipment_name || safePublicId(item?.human_friendly_id, item?.id),
      subtitle: item?.equipment_code || item?.serial_number || null,
      status: item?.status || null,
      priority: item?.criticality_level || null,
      facility_id: facilityId,
      facility_label: facilityLabel,
      equipment_category_id: safePublicId(item?.category?.human_friendly_id, item?.equipment_category_id),
      equipment_category_label: item?.category?.name || null,
      target_path: `/biomedical/equipment-registries/${safePublicId(item?.human_friendly_id, item?.id)}`,
      timeline_at: item?.updated_at || item?.created_at || null,
    };
  }

  if (resource === 'equipment-maintenance-plans') {
    return {
      id: safePublicId(item?.human_friendly_id, item?.id),
      human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
      resource,
      title: item?.plan_name || item?.name || safePublicId(item?.human_friendly_id, item?.id),
      subtitle: item?.equipment_registry?.equipment_name || item?.maintenance_type || null,
      status: item?.status || null,
      priority: null,
      equipment_id: safePublicId(item?.equipment_registry?.human_friendly_id, item?.equipment_registry_id),
      equipment_label: item?.equipment_registry?.equipment_name || item?.equipment_registry?.equipment_code || null,
      next_due_at: item?.next_due_at || null,
      target_path: `/biomedical/equipment-maintenance-plans/${safePublicId(item?.human_friendly_id, item?.id)}`,
      timeline_at: item?.next_due_at || item?.updated_at || item?.created_at || null,
    };
  }

  if (resource === 'equipment-work-orders') {
    return {
      id: safePublicId(item?.human_friendly_id, item?.id),
      human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
      resource,
      title: item?.title || safePublicId(item?.human_friendly_id, item?.id),
      subtitle: item?.equipment_registry?.equipment_name || item?.description || null,
      status: item?.status || null,
      priority: item?.priority || null,
      equipment_id: safePublicId(item?.equipment_registry?.human_friendly_id, item?.equipment_registry_id),
      equipment_label: item?.equipment_registry?.equipment_name || item?.equipment_registry?.equipment_code || null,
      engineer_id: engineer?.id || null,
      engineer_label: engineer?.label || null,
      target_path: `/biomedical/equipment-work-orders/${safePublicId(item?.human_friendly_id, item?.id)}`,
      timeline_at: item?.opened_at || item?.updated_at || item?.created_at || null,
    };
  }

  const equipmentId = safePublicId(item?.equipment_registry?.human_friendly_id, item?.equipment_registry_id);
  const equipmentLabel = item?.equipment_registry?.equipment_name || item?.equipment_registry?.equipment_code || null;

  return {
    id: safePublicId(item?.human_friendly_id, item?.id),
    human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
    resource,
    title: item?.title || item?.name || item?.part_name || item?.provider_name || item?.contract_number || safePublicId(item?.human_friendly_id, item?.id),
    subtitle: equipmentLabel || item?.description || item?.status || null,
    status: item?.status || item?.result || null,
    priority: item?.severity || item?.impact_level || null,
    equipment_id: equipmentId,
    equipment_label: equipmentLabel,
    facility_id: facilityId,
    facility_label: facilityLabel,
    target_path: `/biomedical/${resource}/${safePublicId(item?.human_friendly_id, item?.id)}`,
    timeline_at:
      item?.next_due_at ||
      item?.issued_at ||
      item?.captured_at ||
      item?.occurred_at ||
      item?.started_at ||
      item?.calibrated_at ||
      item?.tested_at ||
      item?.created_at ||
      null,
  };
};

const buildMaps = (lookups = {}) => {
  const facilityMap = new Map(
    (lookups.facilities || []).map((entry) => [
      entry.id,
      { id: safePublicId(entry.human_friendly_id, entry.id), label: entry.name },
    ])
  );

  const engineerMap = new Map();
  (lookups.engineerRoles || []).forEach((entry) => {
    if (!entry?.user?.id || engineerMap.has(entry.user.id)) return;
    engineerMap.set(entry.user.id, {
      id: safePublicId(entry.user.human_friendly_id, entry.user.id),
      label: entry.user.email || entry.user.position_title || '-',
      role: entry.role?.name || null,
    });
  });

  return {
    facilityMap,
    engineerMap,
  };
};

const resolveScopedFilters = async (filters = {}, user = {}) => {
  const tenantId = user?.tenant_id || user?.tenantId || null;
  const scopedFilters = {
    tenantId,
    status: normalizeString(filters.status) || undefined,
    priority: normalizeString(filters.priority) || undefined,
    search: normalizeString(filters.search) || undefined,
    queue: normalizeString(filters.queue) || undefined,
    datePreset: normalizeString(filters.date_preset) || undefined,
  };

  scopedFilters.facilityId = await resolveIdentifierForFilter({
    value: filters.facility_id || user?.facility_id || user?.facilityId,
    model: 'facility',
    where: tenantId ? { tenant_id: tenantId } : {},
  });

  scopedFilters.equipmentId = await resolveIdentifierForFilter({
    value: filters.equipment_id,
    model: 'equipment_registry',
    where: tenantId ? { tenant_id: tenantId } : {},
  });

  scopedFilters.engineerId = await resolveIdentifierForFilter({
    value: filters.engineer_id,
    model: 'user',
    where: tenantId ? { tenant_id: tenantId } : {},
  });

  return scopedFilters;
};

const getWorkspace = async (filters = {}, page = 1, limit = 20, sortBy, order = 'desc', user = {}) => {
  const panel = normalizeString(filters.panel) || DEFAULT_PANEL;
  const resource = normalizeString(filters.resource) || DEFAULT_RESOURCE_BY_PANEL[panel] || DEFAULT_RESOURCE_BY_PANEL[DEFAULT_PANEL];
  const scopedFilters = await resolveScopedFilters(filters, user);
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy || 'updated_at']: order === 'asc' ? 'asc' : 'desc' };

  const [summary, queueCounts, listResult, lookups] = await Promise.all([
    biomedicalWorkspaceRepository.findSummary(scopedFilters),
    biomedicalWorkspaceRepository.findQueueCounts(scopedFilters),
    biomedicalWorkspaceRepository.findItems({ resource, filters: scopedFilters, skip, take: limit, orderBy }),
    biomedicalWorkspaceRepository.findLookups(scopedFilters),
  ]);

  const maps = buildMaps(lookups);

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
      priority: normalizeString(filters.priority) || null,
      facility_id: safePublicId(undefined, scopedFilters.facilityId),
      equipment_id: safePublicId(undefined, scopedFilters.equipmentId),
      engineer_id: safePublicId(undefined, scopedFilters.engineerId),
      date_preset: normalizeString(filters.date_preset) || null,
      id: normalizeString(filters.id) || null,
      action: normalizeString(filters.action) || null,
    },
    lookups: {
      facilities: (lookups.facilities || []).map((entry) =>
        mapLookupOption(entry, entry.name, entry.facility_type || null, { facility_type: entry.facility_type || null })
      ),
      rooms: (lookups.rooms || []).map((entry) =>
        mapLookupOption(entry, entry.name, null, {
          facility_id: safePublicId(undefined, entry.facility_id),
        })
      ),
      equipment: (lookups.equipment || []).map((entry) =>
        mapLookupOption(entry, entry.equipment_name, entry.equipment_code || entry.status || null, { status: entry.status || null })
      ),
      categories: (lookups.categories || []).map((entry) =>
        mapLookupOption(entry, entry.name, entry.code || entry.risk_class || null, { risk_class: entry.risk_class || null })
      ),
      providers: (lookups.providers || []).map((entry) =>
        mapLookupOption(entry, entry.name, entry.contact_name || entry.status || null, { status: entry.status || null })
      ),
      engineers: Array.from(maps.engineerMap.values()).map((entry) => ({ id: entry.id, label: entry.label, subtitle: entry.role, meta: { role: entry.role } })),
      statuses: STATUS_OPTIONS.map((entry) => ({ id: entry, label: entry, subtitle: null, meta: null })),
      priorities: PRIORITY_OPTIONS.map((entry) => ({ id: entry, label: entry, subtitle: null, meta: null })),
      queues: QUEUE_DEFINITIONS.map((entry) => ({ id: entry.id, label: entry.id, subtitle: entry.panel, meta: { resource: entry.resource } })),
    },
    items: (listResult.items || []).map((item) => mapItem(resource, item, maps)),
    pagination: buildPagination(page, limit, Number(listResult.total || 0)),
    spotlight: mapSpotlight(queueCounts),
  };
};

const getLookups = async (filters = {}, user = {}) => {
  const scopedFilters = await resolveScopedFilters(filters, user);
  const lookups = await biomedicalWorkspaceRepository.findLookups(scopedFilters);
  const maps = buildMaps(lookups);

  return {
    facilities: (lookups.facilities || []).map((entry) =>
      mapLookupOption(entry, entry.name, entry.facility_type || null, { facility_type: entry.facility_type || null })
    ),
    rooms: (lookups.rooms || []).map((entry) =>
      mapLookupOption(entry, entry.name, null, {
        facility_id: safePublicId(undefined, entry.facility_id),
      })
    ),
    equipment: (lookups.equipment || []).map((entry) =>
      mapLookupOption(entry, entry.equipment_name, entry.equipment_code || entry.status || null, { status: entry.status || null })
    ),
    categories: (lookups.categories || []).map((entry) =>
      mapLookupOption(entry, entry.name, entry.code || entry.risk_class || null, { risk_class: entry.risk_class || null })
    ),
    providers: (lookups.providers || []).map((entry) =>
      mapLookupOption(entry, entry.name, entry.contact_name || entry.status || null, { status: entry.status || null })
    ),
    engineers: Array.from(maps.engineerMap.values()).map((entry) => ({ id: entry.id, label: entry.label, subtitle: entry.role, meta: { role: entry.role } })),
  };
};

const createFaultReport = async (payload = {}, user = {}, ipAddress = null) => {
  const tenantId = user?.tenant_id || user?.tenantId || null;
  const reportedEquipmentName = normalizeString(payload.reported_equipment_name);
  const equipmentId = await resolveIdentifierForFilter({
    value: payload.equipment_id,
    model: 'equipment_registry',
    where: tenantId ? { tenant_id: tenantId } : {},
  });
  const facilityId = await resolveIdentifierForFilter({
    value: payload.facility_id || user?.facility_id || user?.facilityId,
    model: 'facility',
    where: tenantId ? { tenant_id: tenantId } : {},
  });
  const roomId = await resolveIdentifierForFilter({
    value: payload.room_id,
    model: 'room',
    where: tenantId ? { tenant_id: tenantId } : {},
  });
  const encounterId = payload?.context?.encounter_id
    ? await resolveModelIdByIdentifier({
        model: 'encounter',
        identifier: payload.context.encounter_id,
        where: tenantId ? { tenant_id: tenantId } : {},
      })
    : null;

  let equipment;
  let isPlaceholderEquipment = false;

  if (equipmentId) {
    equipment = await biomedicalWorkspaceRepository.resolveEquipmentRegistry({
      tenantId,
      equipmentId,
    });
  } else if (reportedEquipmentName) {
    equipment =
      await biomedicalWorkspaceRepository.createPlaceholderEquipmentRegistry({
        tenantId,
        facilityId,
        reportedEquipmentName,
        description: payload.description,
        sourceScope: payload.source_scope,
        sourceRoute: payload.source_route,
      });
    isPlaceholderEquipment = true;
  } else {
    throw new HttpError('errors.validation.field.required', 400, [
      { field: 'equipment_id' },
    ]);
  }

  const result = await biomedicalWorkspaceRepository.createFaultReport({
    tenantId,
    facilityId,
    roomId,
    equipment,
    reportedByUserId: user?.id || user?.user_id || null,
    severity: payload.severity,
    priority: payload.priority,
    symptoms: payload.symptoms,
    patientSafetyRisk: Boolean(payload.patient_safety_risk),
    description: payload.description,
    sourceScope: payload.source_scope,
    sourceRoute: payload.source_route,
    evidenceManifest: payload.evidence_manifest || [],
    context: payload.context || {},
    encounterId,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: user?.id || user?.user_id || null,
    action: 'CREATE',
    entity: 'biomedical_fault_report',
    entity_id: result.workOrder.id,
    diff: {
      after: {
        equipment_work_order_id: result.workOrder.id,
        equipment_registry_id: equipment.id,
        is_placeholder_equipment: isPlaceholderEquipment,
        severity: payload.severity,
        priority: payload.priority,
      },
    },
    ip_address: ipAddress,
  }).catch(() => {});

  const recipientIds = await biomedicalWorkspaceRepository.findNotificationRecipients({ tenantId });
  const workOrderPublicId = safePublicId(
    result.workOrder.human_friendly_id,
    result.workOrder.id
  );
  const targetPath = buildWorkspacePath({
    panel: 'work-orders',
    resource: 'equipment-work-orders',
    queue: 'OPEN_WORK_ORDERS',
    id: workOrderPublicId,
    action: 'triage',
  });
  const wsPayload = {
    equipment_work_order_id: workOrderPublicId,
    equipment_id: safePublicId(equipment.human_friendly_id, equipment.id),
    equipment_label: equipment.equipment_name || null,
    severity: payload.severity,
    priority: payload.priority,
    patient_safety_risk: Boolean(payload.patient_safety_risk),
    is_placeholder_equipment: isPlaceholderEquipment,
  };

  if (recipientIds.length > 0) {
    emitToUsers(recipientIds, BIOMEDICAL_EVENTS.BIOMEDICAL_FAULT_REPORTED, wsPayload);
    emitToUsers(recipientIds, BIOMEDICAL_EVENTS.BIOMEDICAL_WORKSPACE_UPDATED, wsPayload);
    await createAndEmitFaultNotifications({
      tenantId,
      recipientUserIds: recipientIds,
      targetPath,
      contextPublicId: workOrderPublicId,
      equipment,
      severity: payload.severity,
      priority: payload.priority,
      patientSafetyRisk: Boolean(payload.patient_safety_risk),
      isPlaceholderEquipment,
    });
  }

  return {
    equipment_work_order: {
      id: workOrderPublicId,
      human_friendly_id: workOrderPublicId,
      status: result.workOrder.status,
      priority: result.workOrder.priority,
    },
    fault_report: result.incidentReport
      ? {
          id: safePublicId(result.incidentReport.human_friendly_id, result.incidentReport.id),
          human_friendly_id: safePublicId(result.incidentReport.human_friendly_id, result.incidentReport.id),
          status: result.incidentReport.status,
          severity: result.incidentReport.severity,
        }
      : null,
    downtime_log: result.downtimeLog
      ? {
          id: safePublicId(result.downtimeLog.human_friendly_id, result.downtimeLog.id),
          human_friendly_id: safePublicId(result.downtimeLog.human_friendly_id, result.downtimeLog.id),
        }
      : null,
    clinical_alert: result.clinicalAlert
      ? {
          id: safePublicId(result.clinicalAlert.human_friendly_id, result.clinicalAlert.id),
          human_friendly_id: safePublicId(result.clinicalAlert.human_friendly_id, result.clinicalAlert.id),
        }
      : null,
    deep_link: targetPath,
  };
};

module.exports = {
  getWorkspace,
  getLookups,
  createFaultReport,
};
