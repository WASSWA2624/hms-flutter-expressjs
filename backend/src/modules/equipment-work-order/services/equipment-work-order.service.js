const equipmentWorkOrderRepository = require('@repositories/equipment-work-order/equipment-work-order.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter, resolveIdentifierForPayload, resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { emitToUsers, BIOMEDICAL_EVENTS } = require('@lib/websocket');

const normalizeString = (value) => String(value || '').trim();
const displayId = (record = {}) => resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id);

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: page * limit < total,
  hasPreviousPage: page > 1,
});

const mapEquipmentWorkOrder = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    id: displayId(record),
    human_friendly_id: displayId(record),
    tenant_id: resolvePublicIdentifier(undefined, record.tenant_id),
    equipment_registry_id: resolvePublicIdentifier(record?.equipment_registry?.human_friendly_id, record?.equipment_registry_id),
    equipment_registry_label: record?.equipment_registry?.equipment_name || record?.equipment_registry?.equipment_code || null,
    maintenance_plan_id: resolvePublicIdentifier(record?.maintenance_plan?.human_friendly_id, record?.maintenance_plan_id),
    maintenance_plan_label: record?.maintenance_plan?.plan_name || null,
    title: record.title || null,
    description: record.description || null,
    priority: record.priority || null,
    status: record.status || null,
    issue_source: record.issue_source || null,
    reported_by_user_id: resolvePublicIdentifier(undefined, record.reported_by_user_id),
    assigned_engineer_user_id: resolvePublicIdentifier(undefined, record.assigned_engineer_user_id),
    opened_at: record.opened_at || null,
    started_at: record.started_at || null,
    completed_at: record.completed_at || null,
    closed_at: record.closed_at || null,
    downtime_started_at: record.downtime_started_at || null,
    downtime_ended_at: record.downtime_ended_at || null,
    resolution_notes: record.resolution_notes || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
  };
};

const resolveWorkOrderId = async (id) => {
  const resolvedId = await resolveModelIdByIdentifier({
    model: 'equipment_work_order',
    identifier: id,
  });

  return resolvedId || id;
};

const resolveListFilters = async (filters = {}, page = 1, limit = 20) => {
  const resolvedFilters = {};

  if (filters.tenant_id !== undefined) {
    const tenantId = await resolveIdentifierForFilter({ value: filters.tenant_id, model: 'tenant' });
    if (tenantId === null) {
      return {
        equipmentWorkOrders: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (tenantId !== undefined) resolvedFilters.tenant_id = tenantId;
  }

  if (filters.equipment_registry_id !== undefined) {
    const equipmentRegistryId = await resolveIdentifierForFilter({
      value: filters.equipment_registry_id,
      model: 'equipment_registry',
      where: resolvedFilters.tenant_id ? { tenant_id: resolvedFilters.tenant_id } : {},
    });
    if (equipmentRegistryId === null) {
      return {
        equipmentWorkOrders: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (equipmentRegistryId !== undefined) resolvedFilters.equipment_registry_id = equipmentRegistryId;
  }

  if (filters.assigned_engineer_user_id !== undefined) {
    const engineerId = await resolveIdentifierForFilter({
      value: filters.assigned_engineer_user_id,
      model: 'user',
      where: resolvedFilters.tenant_id ? { tenant_id: resolvedFilters.tenant_id } : {},
    });
    if (engineerId === null) {
      return {
        equipmentWorkOrders: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (engineerId !== undefined) resolvedFilters.assigned_engineer_user_id = engineerId;
  }

  if (normalizeString(filters.search)) resolvedFilters.search = normalizeString(filters.search);
  if (filters.status) resolvedFilters.status = filters.status;
  if (filters.priority) resolvedFilters.priority = filters.priority;

  return resolvedFilters;
};

const resolvePayload = async (data = {}, existing = null, context = {}) => {
  const payload = { ...data };
  const tenantId = existing?.equipment_registry?.tenant_id || context.tenant_id || null;

  if (Object.prototype.hasOwnProperty.call(payload, 'tenant_id')) {
    payload.tenant_id = await resolveIdentifierForPayload({
      value: payload.tenant_id,
      field: 'tenant_id',
      model: 'tenant',
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'equipment_registry_id')) {
    payload.equipment_registry_id = await resolveIdentifierForPayload({
      value: payload.equipment_registry_id,
      field: 'equipment_registry_id',
      model: 'equipment_registry',
      where: tenantId ? { tenant_id: tenantId } : {},
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'maintenance_plan_id')) {
    payload.maintenance_plan_id = await resolveIdentifierForPayload({
      value: payload.maintenance_plan_id,
      field: 'maintenance_plan_id',
      model: 'equipment_maintenance_plan',
      nullable: true,
      where: tenantId ? { tenant_id: tenantId } : {},
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'maintenance_request_id')) {
    payload.maintenance_request_id = await resolveIdentifierForPayload({
      value: payload.maintenance_request_id,
      field: 'maintenance_request_id',
      model: 'maintenance_request',
      nullable: true,
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'reported_by_user_id')) {
    payload.reported_by_user_id = await resolveIdentifierForPayload({
      value: payload.reported_by_user_id,
      field: 'reported_by_user_id',
      model: 'user',
      nullable: true,
      where: tenantId ? { tenant_id: tenantId } : {},
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'assigned_engineer_user_id')) {
    payload.assigned_engineer_user_id = await resolveIdentifierForPayload({
      value: payload.assigned_engineer_user_id,
      field: 'assigned_engineer_user_id',
      model: 'user',
      nullable: true,
      where: tenantId ? { tenant_id: tenantId } : {},
    });
  }

  if (payload.started_at) payload.started_at = new Date(payload.started_at);
  if (payload.opened_at) payload.opened_at = new Date(payload.opened_at);
  if (payload.completed_at) payload.completed_at = new Date(payload.completed_at);
  if (payload.closed_at) payload.closed_at = new Date(payload.closed_at);
  if (payload.downtime_started_at) payload.downtime_started_at = new Date(payload.downtime_started_at);
  if (payload.downtime_ended_at) payload.downtime_ended_at = new Date(payload.downtime_ended_at);

  return payload;
};

const emitWorkOrderEvent = async (record, event) => {
  const tenantId = record?.equipment_registry?.tenant_id || null;
  if (!tenantId) return;

  const recipientIds = await equipmentWorkOrderRepository.findRecipientUserIds(tenantId);
  if (!recipientIds.length) return;

  const payload = {
    equipment_work_order_id: displayId(record),
    status: record.status,
    priority: record.priority || null,
    equipment_registry_id: resolvePublicIdentifier(record?.equipment_registry?.human_friendly_id, record?.equipment_registry_id),
  };

  emitToUsers(recipientIds, event, payload);
  emitToUsers(recipientIds, BIOMEDICAL_EVENTS.BIOMEDICAL_WORKSPACE_UPDATED, payload);
};

const listEquipmentWorkOrders = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
  const resolvedFilters = await resolveListFilters(filters, page, limit);
  if (resolvedFilters.equipmentWorkOrders && resolvedFilters.pagination) return resolvedFilters;

  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };
  const [items, total] = await Promise.all([
    equipmentWorkOrderRepository.findMany(resolvedFilters, skip, limit, orderBy),
    equipmentWorkOrderRepository.count(resolvedFilters),
  ]);

  return {
    equipmentWorkOrders: items.map(mapEquipmentWorkOrder),
    pagination: buildPagination(page, limit, total),
  };
};

const getEquipmentWorkOrderById = async (id) => {
  const resolvedId = await resolveWorkOrderId(id);
  const item = await equipmentWorkOrderRepository.findById(resolvedId);
  if (!item) throw new HttpError('errors.equipment_work_order.not_found', 404);
  return mapEquipmentWorkOrder(item);
};

const createEquipmentWorkOrder = async (data, context = {}) => {
  const payload = await resolvePayload(data, null, context);
  const item = await equipmentWorkOrderRepository.create(payload);
  const tenantId = item?.equipment_registry?.tenant_id || payload.tenant_id || context.tenant_id;
  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id || context.user?.id,
    action: 'CREATE',
    entity: 'equipment_work_order',
    entity_id: item.id,
    diff: { after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  await emitWorkOrderEvent(item, BIOMEDICAL_EVENTS.BIOMEDICAL_WORK_ORDER_ASSIGNED);
  return mapEquipmentWorkOrder(item);
};

const updateEquipmentWorkOrder = async (id, data, context = {}) => {
  const resolvedId = await resolveWorkOrderId(id);
  const before = await equipmentWorkOrderRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.equipment_work_order.not_found', 404);
  const payload = await resolvePayload(data, before, context);
  const item = await equipmentWorkOrderRepository.update(resolvedId, payload);
  createAuditLog({
    tenant_id: before?.equipment_registry?.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_work_order',
    entity_id: item.id,
    diff: { before, after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  await emitWorkOrderEvent(item, BIOMEDICAL_EVENTS.BIOMEDICAL_WORK_ORDER_ASSIGNED);
  return mapEquipmentWorkOrder(item);
};

const deleteEquipmentWorkOrder = async (id, context = {}) => {
  const resolvedId = await resolveWorkOrderId(id);
  const before = await equipmentWorkOrderRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.equipment_work_order.not_found', 404);
  await equipmentWorkOrderRepository.softDelete(resolvedId);
  createAuditLog({
    tenant_id: before?.equipment_registry?.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'DELETE',
    entity: 'equipment_work_order',
    entity_id: before.id,
    diff: { before },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
};

const startEquipmentWorkOrder = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveWorkOrderId(id);
  const before = await equipmentWorkOrderRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.equipment_work_order.not_found', 404);

  const currentStatus = String(before.status || '').toUpperCase();
  if (['COMPLETED', 'CLOSED', 'CANCELLED', 'RETURNED_TO_SERVICE'].includes(currentStatus)) {
    throw new HttpError('errors.equipment_work_order.cannot_start_terminal_status', 400);
  }

  const item = await equipmentWorkOrderRepository.update(resolvedId, {
    status: 'IN_REPAIR',
    started_at: data.started_at ? new Date(data.started_at) : new Date()
  });

  createAuditLog({
    tenant_id: before?.equipment_registry?.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_work_order',
    entity_id: item.id,
    diff: {
      before,
      after: item,
      metadata: {
        notes: data.notes || null
      }
    },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});

  await emitWorkOrderEvent(item, BIOMEDICAL_EVENTS.BIOMEDICAL_WORK_ORDER_STARTED);
  return mapEquipmentWorkOrder(item);
};

const returnToServiceEquipmentWorkOrder = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveWorkOrderId(id);
  const before = await equipmentWorkOrderRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.equipment_work_order.not_found', 404);

  if (!before.started_at) {
    throw new HttpError('errors.equipment_work_order.cannot_return_before_start', 400);
  }

  const evidenceManifest = Array.isArray(data.verification_evidence_manifest)
    ? data.verification_evidence_manifest.filter((entry) => entry && typeof entry === 'object')
    : [];

  if (evidenceManifest.length === 0) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'verification_evidence_manifest' }]);
  }

  const notes = [before.resolution_notes, data.notes ? `[RETURN_TO_SERVICE] ${data.notes}` : null, `[EVIDENCE] ${JSON.stringify(evidenceManifest)}`]
    .filter(Boolean)
    .join('\n\n');

  const item = await equipmentWorkOrderRepository.update(resolvedId, {
    status: 'RETURNED_TO_SERVICE',
    completed_at: new Date(),
    closed_at: new Date(),
    resolution_notes: notes,
  });

  createAuditLog({
    tenant_id: before?.equipment_registry?.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_work_order',
    entity_id: item.id,
    diff: {
      before,
      after: item,
      metadata: {
        verification_evidence_manifest: evidenceManifest,
      }
    },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});

  await emitWorkOrderEvent(item, BIOMEDICAL_EVENTS.BIOMEDICAL_WORK_ORDER_RETURNED_TO_SERVICE);
  return mapEquipmentWorkOrder(item);
};

module.exports = {
  listEquipmentWorkOrders,
  getEquipmentWorkOrderById,
  createEquipmentWorkOrder,
  updateEquipmentWorkOrder,
  deleteEquipmentWorkOrder,
  startEquipmentWorkOrder,
  returnToServiceEquipmentWorkOrder
};
