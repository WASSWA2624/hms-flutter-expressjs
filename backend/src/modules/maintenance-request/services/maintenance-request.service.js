const prisma = require('@prisma/client');
const maintenanceRequestRepository = require('@repositories/maintenance-request/maintenance-request.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolvePublicIdentifier, resolveIdentifierForFilter, resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { emitToUsers, HOUSEKEEPING_EVENTS } = require('@lib/websocket');

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

const mapMaintenanceRequest = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    id: displayId(record),
    human_friendly_id: displayId(record),
    status: record.status || null,
    description: record.description || null,
    reported_at: record.reported_at || null,
    resolved_at: record.resolved_at || null,
    facility_id: resolvePublicIdentifier(record?.facility?.human_friendly_id, record?.facility_id),
    facility_label: record?.facility?.name || null,
    asset_id: resolvePublicIdentifier(record?.asset?.human_friendly_id, record?.asset_id),
    asset_label: record?.asset?.name || record?.asset?.asset_tag || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
  };
};

const resolveListFilters = async (filters = {}, page = 1, limit = 20) => {
  const resolvedFilters = {};

  if (filters.facility_id !== undefined) {
    const facilityId = await resolveIdentifierForFilter({
      value: filters.facility_id,
      model: 'facility',
    });
    if (facilityId === null) {
      return {
        maintenanceRequests: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (facilityId !== undefined) resolvedFilters.facility_id = facilityId;
  }

  if (filters.asset_id !== undefined) {
    const assetId = await resolveIdentifierForFilter({
      value: filters.asset_id,
      model: 'asset',
    });
    if (assetId === null) {
      return {
        maintenanceRequests: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (assetId !== undefined) resolvedFilters.asset_id = assetId;
  }

  if (filters.status) resolvedFilters.status = filters.status;
  if (normalizeString(filters.search)) resolvedFilters.search = normalizeString(filters.search);

  return resolvedFilters;
};

const resolvePayload = async (data = {}, existing = null) => {
  const payload = { ...data };
  const tenantId = existing?.asset?.tenant_id || null;

  if (Object.prototype.hasOwnProperty.call(payload, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      nullable: true,
      where: tenantId ? { tenant_id: tenantId } : {},
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'asset_id')) {
    payload.asset_id = await resolveIdentifierForPayload({
      value: payload.asset_id,
      field: 'asset_id',
      model: 'asset',
      nullable: true,
      where: tenantId ? { tenant_id: tenantId } : {},
    });
  }

  if (payload.reported_at) payload.reported_at = new Date(payload.reported_at);
  if (Object.prototype.hasOwnProperty.call(payload, 'resolved_at') && payload.resolved_at) {
    payload.resolved_at = new Date(payload.resolved_at);
  }

  return payload;
};

const resolveRequestId = async (identifier) => {
  const resolvedId = await resolveModelIdByIdentifier({
    model: 'maintenance_request',
    identifier,
  });

  return resolvedId || identifier;
};

const findRecipientIds = async (tenantId) => {
  if (!tenantId) return [];
  const rows = await prisma.user_role.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      role: {
        name: { in: ['BIOMED', 'OPERATIONS', 'FACILITY_ADMIN', 'TENANT_ADMIN'] },
        deleted_at: null,
      },
      user: { deleted_at: null },
    },
    select: { user_id: true },
  });
  return Array.from(new Set(rows.map((entry) => entry.user_id).filter(Boolean)));
};

const emitMaintenanceRequestUpdate = async (record, event) => {
  const tenantId = record?.asset?.tenant_id || null;
  const recipientIds = await findRecipientIds(tenantId);
  if (!recipientIds.length) return;

  const payload = {
    maintenance_request_id: displayId(record),
    status: record?.status || null,
    asset_id: resolvePublicIdentifier(record?.asset?.human_friendly_id, record?.asset_id),
    facility_id: resolvePublicIdentifier(record?.facility?.human_friendly_id, record?.facility_id),
  };

  emitToUsers(recipientIds, event, payload);
  emitToUsers(recipientIds, HOUSEKEEPING_EVENTS.HOUSEKEEPING_WORKSPACE_UPDATED, payload);
};

const listMaintenanceRequests = async (filters, page, limit, sortBy, order) => {
  try {
    const resolvedFilters = await resolveListFilters(filters, page, limit);
    if (resolvedFilters.maintenanceRequests && resolvedFilters.pagination) return resolvedFilters;

    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const [maintenanceRequests, total] = await Promise.all([
      maintenanceRequestRepository.findMany(resolvedFilters, skip, limit, orderBy),
      maintenanceRequestRepository.count(resolvedFilters),
    ]);

    return {
      maintenanceRequests: maintenanceRequests.map(mapMaintenanceRequest),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getMaintenanceRequestById = async (id) => {
  try {
    const resolvedId = await resolveRequestId(id);
    const maintenanceRequest = await maintenanceRequestRepository.findById(resolvedId);

    if (!maintenanceRequest) {
      throw new HttpError('errors.maintenance_request.not_found', 404);
    }

    return mapMaintenanceRequest(maintenanceRequest);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createMaintenanceRequest = async (data, userId, ipAddress) => {
  try {
    const processedData = await resolvePayload(data);
    const maintenanceRequest = await maintenanceRequestRepository.create(processedData);

    createAuditLog({
      tenant_id: maintenanceRequest?.asset?.tenant_id || null,
      user_id: userId,
      action: 'CREATE',
      entity: 'maintenance_request',
      entity_id: maintenanceRequest.id,
      diff: { after: maintenanceRequest },
      ip_address: ipAddress,
    }).catch(() => {});

    await emitMaintenanceRequestUpdate(maintenanceRequest, HOUSEKEEPING_EVENTS.HOUSEKEEPING_WORKSPACE_UPDATED);
    return mapMaintenanceRequest(maintenanceRequest);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateMaintenanceRequest = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveRequestId(id);
    const before = await maintenanceRequestRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.maintenance_request.not_found', 404);
    }

    const processedData = await resolvePayload(data, before);
    const maintenanceRequest = await maintenanceRequestRepository.update(resolvedId, processedData);

    createAuditLog({
      tenant_id: before?.asset?.tenant_id || null,
      user_id: userId,
      action: 'UPDATE',
      entity: 'maintenance_request',
      entity_id: maintenanceRequest.id,
      diff: { before, after: maintenanceRequest },
      ip_address: ipAddress,
    }).catch(() => {});

    await emitMaintenanceRequestUpdate(maintenanceRequest, HOUSEKEEPING_EVENTS.HOUSEKEEPING_WORKSPACE_UPDATED);
    return mapMaintenanceRequest(maintenanceRequest);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteMaintenanceRequest = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveRequestId(id);
    const before = await maintenanceRequestRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.maintenance_request.not_found', 404);
    }

    await maintenanceRequestRepository.softDelete(resolvedId);

    createAuditLog({
      tenant_id: before?.asset?.tenant_id || null,
      user_id: userId,
      action: 'DELETE',
      entity: 'maintenance_request',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const triageMaintenanceRequest = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveRequestId(id);
    const before = await maintenanceRequestRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.maintenance_request.not_found', 404);
    }

    if (before.status === 'COMPLETED' || before.status === 'CANCELLED') {
      throw new HttpError('errors.maintenance_request.cannot_triage_terminal_status', 400);
    }

    const engineerId = await resolveIdentifierForFilter({
      value: data.assigned_engineer,
      model: 'user',
      where: before?.asset?.tenant_id ? { tenant_id: before.asset.tenant_id } : {},
    });

    const summaryParts = [];
    if (engineerId) summaryParts.push(`assigned_engineer_id=${engineerId}`);
    if (data.sla_hours) summaryParts.push(`sla_hours=${data.sla_hours}`);
    if (data.triage_summary) summaryParts.push(`triage_summary=${data.triage_summary}`);

    const updateData = {
      status: data.status || 'IN_PROGRESS',
    };

    if (summaryParts.length > 0) {
      const existingDescription = before.description ? `${before.description}\n\n` : '';
      updateData.description = `${existingDescription}[TRIAGE] ${summaryParts.join('; ')}`.trim();
    }

    const maintenanceRequest = await maintenanceRequestRepository.update(resolvedId, updateData);

    createAuditLog({
      tenant_id: before?.asset?.tenant_id || null,
      user_id: userId,
      action: 'UPDATE',
      entity: 'maintenance_request',
      entity_id: maintenanceRequest.id,
      diff: {
        before,
        after: maintenanceRequest,
        metadata: {
          assigned_engineer_id: engineerId || null,
          sla_hours: data.sla_hours || null,
          triage_summary: data.triage_summary || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    await emitMaintenanceRequestUpdate(maintenanceRequest, HOUSEKEEPING_EVENTS.MAINTENANCE_REQUEST_TRIAGED);
    return mapMaintenanceRequest(maintenanceRequest);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const convertMaintenanceRequestToWorkOrder = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveRequestId(id);
    const requestRecord = await maintenanceRequestRepository.findById(resolvedId);

    if (!requestRecord) {
      throw new HttpError('errors.maintenance_request.not_found', 404);
    }

    const tenantId = requestRecord?.asset?.tenant_id || null;
    const equipmentRegistryId = await resolveIdentifierForPayload({
      value: data.equipment_registry_id,
      field: 'equipment_registry_id',
      model: 'equipment_registry',
      where: tenantId ? { tenant_id: tenantId } : {},
    });
    const assignedEngineerUserId = await resolveIdentifierForPayload({
      value: data.assigned_engineer_user_id,
      field: 'assigned_engineer_user_id',
      model: 'user',
      nullable: true,
      where: tenantId ? { tenant_id: tenantId } : {},
    });

    const [updatedRequest, workOrder] = await prisma.$transaction(async (tx) => {
      const updated = await tx.maintenance_request.update({
        where: { id: resolvedId },
        data: {
          status: 'IN_PROGRESS',
          description: [requestRecord.description, data.notes ? `[CONVERT] ${data.notes}` : null].filter(Boolean).join('\n\n'),
        },
        include: {
          facility: { select: { id: true, human_friendly_id: true, name: true } },
          asset: { select: { id: true, human_friendly_id: true, name: true, asset_tag: true, tenant_id: true } },
        },
      });

      const createdWorkOrder = await tx.equipment_work_order.create({
        data: {
          tenant_id: tenantId,
          equipment_registry_id: equipmentRegistryId,
          maintenance_request_id: resolvedId,
          title: data.title,
          description: data.description || requestRecord.description || null,
          priority: data.priority || 'NORMAL',
          status: 'OPEN',
          issue_source: 'MAINTENANCE_REQUEST',
          reported_by_user_id: userId || null,
          assigned_engineer_user_id: assignedEngineerUserId || null,
          downtime_started_at: data.downtime_started_at ? new Date(data.downtime_started_at) : null,
          opened_at: new Date(),
        },
      });

      return [updated, createdWorkOrder];
    });

    const [equipmentRegistry, assignedEngineer] = await Promise.all([
      equipmentRegistryId
        ? prisma.equipment_registry.findUnique({
            where: { id: equipmentRegistryId },
            select: {
              id: true,
              human_friendly_id: true,
              equipment_name: true,
              equipment_code: true,
            },
          })
        : Promise.resolve(null),
      assignedEngineerUserId
        ? prisma.user.findUnique({
            where: { id: assignedEngineerUserId },
            select: {
              id: true,
              human_friendly_id: true,
              email: true,
              position_title: true,
            },
          })
        : Promise.resolve(null),
    ]);

    createAuditLog({
      tenant_id: tenantId,
      user_id: userId,
      action: 'UPDATE',
      entity: 'maintenance_request',
      entity_id: updatedRequest.id,
      diff: {
        before: requestRecord,
        after: updatedRequest,
        metadata: {
          equipment_work_order_id: workOrder.id,
          equipment_registry_id: equipmentRegistryId,
          assigned_engineer_user_id: assignedEngineerUserId || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    await emitMaintenanceRequestUpdate(updatedRequest, HOUSEKEEPING_EVENTS.MAINTENANCE_REQUEST_CONVERTED);

    return {
      maintenance_request: mapMaintenanceRequest(updatedRequest),
      equipment_work_order: {
        id: displayId(workOrder),
        human_friendly_id: displayId(workOrder),
        title: workOrder.title,
        status: workOrder.status,
        priority: workOrder.priority,
        equipment_registry_id: resolvePublicIdentifier(
          equipmentRegistry?.human_friendly_id,
          equipmentRegistryId
        ),
        equipment_registry_label:
          equipmentRegistry?.equipment_name || equipmentRegistry?.equipment_code || null,
        assigned_engineer_user_id: resolvePublicIdentifier(
          assignedEngineer?.human_friendly_id,
          assignedEngineerUserId
        ),
        assigned_engineer_label:
          assignedEngineer?.email || assignedEngineer?.position_title || null,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listMaintenanceRequests,
  getMaintenanceRequestById,
  createMaintenanceRequest,
  updateMaintenanceRequest,
  deleteMaintenanceRequest,
  triageMaintenanceRequest,
  convertMaintenanceRequestToWorkOrder,
};
