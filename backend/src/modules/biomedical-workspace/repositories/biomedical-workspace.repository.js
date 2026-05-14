const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const OPEN_WORK_ORDER_STATUSES = ['OPEN', 'TRIAGED', 'ASSIGNED', 'IN_PROGRESS', 'IN_REPAIR', 'READY_FOR_QA'];
const RETURN_TO_SERVICE_STATUSES = ['IN_REPAIR', 'READY_FOR_QA', 'TESTING'];

const buildEquipmentRegistryWhere = ({ tenantId, facilityId, equipmentId, status, search }) => {
  const where = {
    tenant_id: tenantId,
    deleted_at: null,
  };

  if (facilityId) where.facility_id = facilityId;
  if (equipmentId) where.id = equipmentId;
  if (status) where.status = status;

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { equipment_name: { contains: normalizedSearch } },
          { equipment_code: { contains: normalizedSearch } },
          { serial_number: { contains: normalizedSearch } },
          { manufacturer: { contains: normalizedSearch } },
        ],
      },
    ];
  }

  return where;
};

const buildMaintenancePlanWhere = ({ tenantId, facilityId, equipmentId, status, search, queue, datePreset }) => {
  const where = {
    tenant_id: tenantId,
    deleted_at: null,
  };

  if (facilityId) where.equipment_registry = { facility_id: facilityId };
  if (equipmentId) where.equipment_registry_id = equipmentId;
  if (status) where.status = status;
  if (queue === 'OVERDUE_PM' || datePreset === 'overdue') {
    where.next_due_at = { lt: new Date() };
    where.is_active = true;
  }

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { name: { contains: normalizedSearch } },
          { plan_name: { contains: normalizedSearch } },
          { maintenance_type: { contains: normalizedSearch } },
          { equipment_registry: { equipment_name: { contains: normalizedSearch } } },
        ],
      },
    ];
  }

  return where;
};

const buildWorkOrderWhere = ({ tenantId, facilityId, equipmentId, engineerId, status, priority, search, queue, datePreset }) => {
  const where = {
    tenant_id: tenantId,
    deleted_at: null,
  };

  if (facilityId) where.equipment_registry = { facility_id: facilityId };
  if (equipmentId) where.equipment_registry_id = equipmentId;
  if (engineerId) where.assigned_engineer_user_id = engineerId;
  if (status) where.status = status;
  if (priority) where.priority = priority;

  if (queue === 'OPEN_WORK_ORDERS') {
    where.status = where.status || { in: OPEN_WORK_ORDER_STATUSES };
  } else if (queue === 'RETURN_TO_SERVICE') {
    where.status = where.status || { in: RETURN_TO_SERVICE_STATUSES };
  } else if (datePreset === 'overdue') {
    const overdueAt = new Date();
    overdueAt.setDate(overdueAt.getDate() - 2);
    where.opened_at = { lt: overdueAt };
    where.status = where.status || { in: OPEN_WORK_ORDER_STATUSES };
  }

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { title: { contains: normalizedSearch } },
          { description: { contains: normalizedSearch } },
          { equipment_registry: { equipment_name: { contains: normalizedSearch } } },
          { equipment_registry: { equipment_code: { contains: normalizedSearch } } },
        ],
      },
    ];
  }

  return where;
};

const buildLogWhere = ({ tenantId, facilityId, equipmentId, search, queue, type }) => {
  const where = {
    tenant_id: tenantId,
    deleted_at: null,
  };

  if (facilityId) where.equipment_registry = { facility_id: facilityId };
  if (equipmentId) where.equipment_registry_id = equipmentId;
  if (queue === 'CRITICAL_DOWNTIME' && type === 'downtime') {
    where.ended_at = null;
    where.is_clinically_critical = true;
  }
  if (queue === 'RECALL_ACTIONS' && type === 'recall') {
    where.status = { notIn: ['RESOLVED', 'CLOSED', 'COMPLETED'] };
  }

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { name: { contains: normalizedSearch } },
          { description: { contains: normalizedSearch } },
          { equipment_registry: { equipment_name: { contains: normalizedSearch } } },
          { equipment_registry: { equipment_code: { contains: normalizedSearch } } },
        ],
      },
    ];
  }

  return where;
};

const RESOURCE_CONFIG = {
  'equipment-registries': {
    model: 'equipment_registry',
    where: buildEquipmentRegistryWhere,
    include: {
      category: { select: { id: true, human_friendly_id: true, name: true } },
    },
  },
  'equipment-maintenance-plans': {
    model: 'equipment_maintenance_plan',
    where: buildMaintenancePlanWhere,
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
    },
  },
  'equipment-work-orders': {
    model: 'equipment_work_order',
    where: buildWorkOrderWhere,
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
      maintenance_plan: { select: { id: true, human_friendly_id: true, plan_name: true } },
    },
  },
  'equipment-calibration-logs': {
    model: 'equipment_calibration_log',
    where: (filters) => buildLogWhere({ ...filters, type: 'calibration' }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
      equipment_work_order: { select: { id: true, human_friendly_id: true, title: true } },
    },
  },
  'equipment-safety-test-logs': {
    model: 'equipment_safety_test_log',
    where: (filters) => buildLogWhere({ ...filters, type: 'safety' }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
      equipment_work_order: { select: { id: true, human_friendly_id: true, title: true } },
    },
  },
  'equipment-downtime-logs': {
    model: 'equipment_downtime_log',
    where: (filters) => buildLogWhere({ ...filters, type: 'downtime' }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
      equipment_work_order: { select: { id: true, human_friendly_id: true, title: true } },
    },
  },
  'equipment-incident-reports': {
    model: 'equipment_incident_report',
    where: (filters) => buildLogWhere({ ...filters, type: 'incident' }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
      equipment_work_order: { select: { id: true, human_friendly_id: true, title: true } },
    },
  },
  'equipment-recall-notices': {
    model: 'equipment_recall_notice',
    where: (filters) => buildLogWhere({ ...filters, type: 'recall' }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
      equipment_service_provider: { select: { id: true, human_friendly_id: true, name: true } },
    },
  },
  'equipment-service-providers': {
    model: 'equipment_service_provider',
    where: ({ tenantId, status, search }) => ({
      tenant_id: tenantId,
      deleted_at: null,
      ...(status ? { status } : {}),
      ...(search
        ? {
            OR: [
              { name: { contains: search } },
              { contact_name: { contains: search } },
              { contact_email: { contains: search } },
              { human_friendly_id: { contains: String(search).toUpperCase() } },
            ],
          }
        : {}),
    }),
  },
  'equipment-warranty-contracts': {
    model: 'equipment_warranty_contract',
    where: ({ tenantId, facilityId, equipmentId, status, search }) => ({
      tenant_id: tenantId,
      deleted_at: null,
      ...(facilityId ? { equipment_registry: { facility_id: facilityId } } : {}),
      ...(equipmentId ? { equipment_registry_id: equipmentId } : {}),
      ...(status ? { status } : {}),
      ...(search
        ? {
            OR: [
              { provider_name: { contains: search } },
              { contract_number: { contains: search } },
              { human_friendly_id: { contains: String(search).toUpperCase() } },
              { equipment_registry: { equipment_name: { contains: search } } },
            ],
          }
        : {}),
    }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
    },
  },
  'equipment-spare-parts': {
    model: 'equipment_spare_part',
    where: ({ tenantId, facilityId, equipmentId, search }) => ({
      tenant_id: tenantId,
      deleted_at: null,
      ...(facilityId ? { equipment_registry: { facility_id: facilityId } } : {}),
      ...(equipmentId ? { equipment_registry_id: equipmentId } : {}),
      ...(search
        ? {
            OR: [
              { part_name: { contains: search } },
              { part_number: { contains: search } },
              { manufacturer: { contains: search } },
              { human_friendly_id: { contains: String(search).toUpperCase() } },
            ],
          }
        : {}),
    }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
    },
  },
  'equipment-categories': {
    model: 'equipment_category',
    where: ({ tenantId, search }) => ({
      tenant_id: tenantId,
      deleted_at: null,
      ...(search
        ? {
            OR: [
              { name: { contains: search } },
              { code: { contains: search } },
              { human_friendly_id: { contains: String(search).toUpperCase() } },
            ],
          }
        : {}),
    }),
  },
  'equipment-disposal-transfers': {
    model: 'equipment_disposal_transfer',
    where: ({ tenantId, facilityId, equipmentId, status, search }) => ({
      tenant_id: tenantId,
      deleted_at: null,
      ...(facilityId ? { equipment_registry: { facility_id: facilityId } } : {}),
      ...(equipmentId ? { equipment_registry_id: equipmentId } : {}),
      ...(status ? { status } : {}),
      ...(search
        ? {
            OR: [
              { action_type: { contains: search } },
              { to_organization: { contains: search } },
              { human_friendly_id: { contains: String(search).toUpperCase() } },
              { equipment_registry: { equipment_name: { contains: search } } },
            ],
          }
        : {}),
    }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
    },
  },
  'equipment-utilization-snapshots': {
    model: 'equipment_utilization_snapshot',
    where: ({ tenantId, facilityId, equipmentId, search }) => ({
      tenant_id: tenantId,
      deleted_at: null,
      ...(facilityId ? { equipment_registry: { facility_id: facilityId } } : {}),
      ...(equipmentId ? { equipment_registry_id: equipmentId } : {}),
      ...(search
        ? {
            OR: [
              { name: { contains: search } },
              { human_friendly_id: { contains: String(search).toUpperCase() } },
              { equipment_registry: { equipment_name: { contains: search } } },
            ],
          }
        : {}),
    }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
    },
  },
  'equipment-location-histories': {
    model: 'equipment_location_history',
    where: ({ tenantId, facilityId, equipmentId, search }) => ({
      tenant_id: tenantId,
      deleted_at: null,
      ...(facilityId ? { equipment_registry: { facility_id: facilityId } } : {}),
      ...(equipmentId ? { equipment_registry_id: equipmentId } : {}),
      ...(search
        ? {
            OR: [
              { from_location: { contains: search } },
              { to_location: { contains: search } },
              { human_friendly_id: { contains: String(search).toUpperCase() } },
              { equipment_registry: { equipment_name: { contains: search } } },
            ],
          }
        : {}),
    }),
    include: {
      equipment_registry: { select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true } },
    },
  },
};

const findSummary = async ({ tenantId, facilityId, equipmentId, engineerId }) => {
  const [totalEquipment, overduePm, openWorkOrders, criticalDowntime, activeRecalls] = await Promise.all([
    prisma.equipment_registry.count({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
        ...(facilityId ? { facility_id: facilityId } : {}),
        ...(equipmentId ? { id: equipmentId } : {}),
      },
    }),
    prisma.equipment_maintenance_plan.count({
      where: buildMaintenancePlanWhere({
        tenantId,
        facilityId,
        equipmentId,
        queue: 'OVERDUE_PM',
      }),
    }),
    prisma.equipment_work_order.count({
      where: buildWorkOrderWhere({
        tenantId,
        facilityId,
        equipmentId,
        engineerId,
        queue: 'OPEN_WORK_ORDERS',
      }),
    }),
    prisma.equipment_downtime_log.count({
      where: buildLogWhere({
        tenantId,
        facilityId,
        equipmentId,
        queue: 'CRITICAL_DOWNTIME',
        type: 'downtime',
      }),
    }),
    prisma.equipment_recall_notice.count({
      where: buildLogWhere({
        tenantId,
        facilityId,
        equipmentId,
        queue: 'RECALL_ACTIONS',
        type: 'recall',
      }),
    }),
  ]);

  return {
    total_equipment: totalEquipment,
    overdue_pm: overduePm,
    open_work_orders: openWorkOrders,
    critical_downtime: criticalDowntime,
    active_recalls: activeRecalls,
  };
};

const findQueueCounts = async ({ tenantId, facilityId, equipmentId, engineerId }) => {
  const [overduePm, openWorkOrders, criticalDowntime, recallActions, returnToService] = await Promise.all([
    prisma.equipment_maintenance_plan.count({
      where: buildMaintenancePlanWhere({
        tenantId,
        facilityId,
        equipmentId,
        queue: 'OVERDUE_PM',
      }),
    }),
    prisma.equipment_work_order.count({
      where: buildWorkOrderWhere({
        tenantId,
        facilityId,
        equipmentId,
        engineerId,
        queue: 'OPEN_WORK_ORDERS',
      }),
    }),
    prisma.equipment_downtime_log.count({
      where: buildLogWhere({
        tenantId,
        facilityId,
        equipmentId,
        queue: 'CRITICAL_DOWNTIME',
        type: 'downtime',
      }),
    }),
    prisma.equipment_recall_notice.count({
      where: buildLogWhere({
        tenantId,
        facilityId,
        equipmentId,
        queue: 'RECALL_ACTIONS',
        type: 'recall',
      }),
    }),
    prisma.equipment_work_order.count({
      where: buildWorkOrderWhere({
        tenantId,
        facilityId,
        equipmentId,
        engineerId,
        queue: 'RETURN_TO_SERVICE',
      }),
    }),
  ]);

  return {
    OVERDUE_PM: overduePm,
    OPEN_WORK_ORDERS: openWorkOrders,
    CRITICAL_DOWNTIME: criticalDowntime,
    RECALL_ACTIONS: recallActions,
    RETURN_TO_SERVICE: returnToService,
  };
};

const findItems = async ({ resource, filters, skip, take, orderBy }) => {
  try {
    const config = RESOURCE_CONFIG[resource];
    if (!config) return { items: [], total: 0 };

    const where = config.where(filters);
    const delegate = prisma[config.model];
    const [items, total] = await Promise.all([
      delegate.findMany({ where, skip, take, orderBy, include: config.include }),
      delegate.count({ where }),
    ]);
    return { items, total };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findLookups = async ({ tenantId, facilityId, search }) => {
  try {
    const normalizedSearch = String(search || '').trim();
    const searchUpper = normalizedSearch.toUpperCase();
    const roleNames = ['BIOMED', 'OPERATIONS'];

    const [facilities, rooms, equipment, categories, providers, engineerRoles] = await Promise.all([
      prisma.facility.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(normalizedSearch
            ? { OR: [{ name: { contains: normalizedSearch } }, { human_friendly_id: { contains: searchUpper } }] }
            : {}),
        },
        take: 50,
        orderBy: { name: 'asc' },
        select: { id: true, human_friendly_id: true, name: true, facility_type: true },
      }),
      prisma.room.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(facilityId ? { facility_id: facilityId } : {}),
          ...(normalizedSearch
            ? {
                OR: [
                  { name: { contains: normalizedSearch } },
                  { human_friendly_id: { contains: searchUpper } },
                ],
              }
            : {}),
        },
        take: 50,
        orderBy: { name: 'asc' },
        select: { id: true, human_friendly_id: true, name: true, facility_id: true },
      }),
      prisma.equipment_registry.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(facilityId ? { facility_id: facilityId } : {}),
          ...(normalizedSearch
            ? {
                OR: [
                  { equipment_name: { contains: normalizedSearch } },
                  { equipment_code: { contains: normalizedSearch } },
                  { serial_number: { contains: normalizedSearch } },
                  { human_friendly_id: { contains: searchUpper } },
                ],
              }
            : {}),
        },
        take: 50,
        orderBy: { equipment_name: 'asc' },
        select: { id: true, human_friendly_id: true, equipment_name: true, equipment_code: true, status: true, facility_id: true },
      }),
      prisma.equipment_category.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(normalizedSearch
            ? { OR: [{ name: { contains: normalizedSearch } }, { code: { contains: normalizedSearch } }, { human_friendly_id: { contains: searchUpper } }] }
            : {}),
        },
        take: 50,
        orderBy: { name: 'asc' },
        select: { id: true, human_friendly_id: true, name: true, code: true, risk_class: true },
      }),
      prisma.equipment_service_provider.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(normalizedSearch
            ? {
                OR: [
                  { name: { contains: normalizedSearch } },
                  { contact_name: { contains: normalizedSearch } },
                  { contact_email: { contains: normalizedSearch } },
                  { human_friendly_id: { contains: searchUpper } },
                ],
              }
            : {}),
        },
        take: 50,
        orderBy: { name: 'asc' },
        select: { id: true, human_friendly_id: true, name: true, contact_name: true, status: true },
      }),
      prisma.user_role.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          role: { name: { in: roleNames }, deleted_at: null },
          user: {
            deleted_at: null,
            ...(normalizedSearch
              ? {
                  OR: [
                    { email: { contains: normalizedSearch } },
                    { human_friendly_id: { contains: searchUpper } },
                    { position_title: { contains: normalizedSearch } },
                  ],
                }
              : {}),
          },
        },
        take: 100,
        select: {
          user_id: true,
          role: { select: { name: true } },
          user: { select: { id: true, human_friendly_id: true, email: true, position_title: true } },
        },
      }),
    ]);

    return { facilities, rooms, equipment, categories, providers, engineerRoles };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const resolveEquipmentRegistry = async ({ tenantId, equipmentId }) => {
  const equipment = await prisma.equipment_registry.findFirst({
    where: {
      id: equipmentId,
      tenant_id: tenantId,
      deleted_at: null,
    },
    select: {
      id: true,
      human_friendly_id: true,
      asset_id: true,
      facility_id: true,
      equipment_name: true,
      equipment_code: true,
    },
  });

  if (!equipment) {
    throw new HttpError('errors.equipment_registry.not_found', 404);
  }

  return equipment;
};

const createPlaceholderEquipmentRegistry = async ({
  tenantId,
  facilityId = null,
  reportedEquipmentName,
  description = '',
  sourceScope = '',
  sourceRoute = '',
}) => {
  try {
    const normalizedName = String(reportedEquipmentName || '').trim();
    const normalizedDescription = String(description || '').trim();
    const detailLines = [
      'Placeholder equipment record created from fault report.',
      normalizedDescription ? `fault_report_description=${normalizedDescription}` : null,
      sourceScope ? `source_scope=${sourceScope}` : null,
      sourceRoute ? `source_route=${sourceRoute}` : null,
    ].filter(Boolean);

    return await prisma.equipment_registry.create({
      data: {
        tenant_id: tenantId,
        facility_id: facilityId || null,
        equipment_name: normalizedName,
        name: normalizedName,
        description: detailLines.join('\n'),
        status: 'PENDING_IDENTIFICATION',
        criticality_level: null,
      },
      select: {
        id: true,
        human_friendly_id: true,
        asset_id: true,
        facility_id: true,
        equipment_name: true,
        equipment_code: true,
      },
    });
  } catch (error) {
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findNotificationRecipients = async ({ tenantId }) => {
  const rows = await prisma.user_role.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      role: { name: { in: ['BIOMED', 'OPERATIONS', 'FACILITY_ADMIN', 'TENANT_ADMIN'] }, deleted_at: null },
      user: { deleted_at: null },
    },
    select: { user_id: true },
  });

  return Array.from(new Set(rows.map((entry) => entry.user_id).filter(Boolean)));
};

const createFaultReport = async ({
  tenantId,
  roomId,
  equipment,
  reportedByUserId,
  severity,
  priority,
  symptoms,
  patientSafetyRisk,
  description,
  sourceScope,
  sourceRoute,
  evidenceManifest,
  context,
  encounterId,
}) =>
  prisma.$transaction(async (tx) => {
    const detailLines = [
      `equipment=${equipment.equipment_name}`,
      equipment.equipment_code ? `equipment_code=${equipment.equipment_code}` : null,
      `severity=${severity}`,
      `priority=${priority}`,
      `patient_safety_risk=${patientSafetyRisk ? 'YES' : 'NO'}`,
      `source_scope=${sourceScope}`,
      `source_route=${sourceRoute}`,
      roomId ? `room_id=${roomId}` : null,
      `symptoms=${symptoms}`,
      description ? `description=${description}` : null,
      Array.isArray(evidenceManifest) && evidenceManifest.length > 0 ? `evidence_manifest=${JSON.stringify(evidenceManifest)}` : null,
      context && Object.keys(context).length > 0 ? `context=${JSON.stringify(context)}` : null,
    ].filter(Boolean);

    const workOrder = await tx.equipment_work_order.create({
      data: {
        tenant_id: tenantId,
        equipment_registry_id: equipment.id,
        title: `Fault report: ${equipment.equipment_name}`,
        description: detailLines.join('\n'),
        priority: priority || 'HIGH',
        status: 'OPEN',
        issue_source: 'BIOMEDICAL_FAULT_REPORT',
        reported_by_user_id: reportedByUserId || null,
        opened_at: new Date(),
        downtime_started_at:
          patientSafetyRisk || severity === 'CRITICAL' || severity === 'HIGH'
            ? new Date()
            : null,
      },
    });

    const incidentReport = await tx.equipment_incident_report.create({
      data: {
        tenant_id: tenantId,
        equipment_registry_id: equipment.id,
        equipment_work_order_id: workOrder.id,
        reported_by_user_id: reportedByUserId || null,
        title: `Fault report: ${equipment.equipment_name}`,
        description,
        severity,
        status: 'OPEN',
        patient_impact: patientSafetyRisk,
        hazard_level: severity,
        immediate_action: symptoms,
        occurred_at: new Date(),
      },
    });

    let downtimeLog = null;
    if (patientSafetyRisk || severity === 'CRITICAL' || severity === 'HIGH') {
      downtimeLog = await tx.equipment_downtime_log.create({
        data: {
          tenant_id: tenantId,
          equipment_registry_id: equipment.id,
          description,
          reason: symptoms,
          impact_level: severity,
          is_clinically_critical: patientSafetyRisk || severity === 'CRITICAL',
          started_at: new Date(),
          notes: sourceRoute,
        },
      });
    }

    let clinicalAlert = null;
    if (encounterId && severity === 'CRITICAL') {
      clinicalAlert = await tx.clinical_alert.create({
        data: {
          encounter_id: encounterId,
          severity: 'CRITICAL',
          status: 'NEW',
          source: 'MANUAL',
          message: `Critical equipment fault reported for ${equipment.equipment_name}`,
        },
      });
    }

    return {
      workOrder,
      incidentReport,
      downtimeLog,
      clinicalAlert,
    };
  });

module.exports = {
  findSummary,
  findQueueCounts,
  findItems,
  findLookups,
  resolveEquipmentRegistry,
  createPlaceholderEquipmentRegistry,
  findNotificationRecipients,
  createFaultReport,
};
