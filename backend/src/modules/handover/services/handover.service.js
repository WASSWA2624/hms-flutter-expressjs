const handoverRepository = require('@repositories/handover/handover.repository');
const officeContextRepository = require('@repositories/office-context/office-context.repository');
const { resolveIdentifierForFilter, resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { createAuditLog } = require('@lib/audit');
const { PERMISSIONS } = require('@config/permissions');
const { HttpError } = require('@lib/errors');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { emitLastOfficeEvent, LAST_OFFICE_EVENTS } = require('@lib/last-office/events');
const {
  buildPagination,
  buildRecordEtag,
  createPublicId,
  normalizeString,
  resolveListScopedIdentifiers,
  resolveScopedIdentifiers,
  serializeHandover,
} = require('@lib/last-office/shared');
const { recordWorkflowEvent } = require('@lib/telemetry/metrics');
const { getUserPermissions } = require('@middlewares/auth.middleware');

const SORT_FIELDS = new Set(['created_at', 'updated_at', 'submitted_at', 'accepted_at']);

const resolveHandoverId = async (identifier) => {
  const resolved = await resolveModelIdByIdentifier({
    model: 'handover',
    identifier,
  });

  return resolved || identifier;
};

const ensureScopedRecord = (record, context = {}) => {
  if (!record || record.deleted_at) {
    throw new HttpError('errors.handover.not_found', 404);
  }

  if (context.tenant_id && record.tenant_id !== context.tenant_id) {
    throw new HttpError('errors.handover.not_found', 404);
  }

  if (context.facility_id && record.facility_id && record.facility_id !== context.facility_id) {
    throw new HttpError('errors.handover.not_found', 404);
  }

  if (context.branch_id && record.branch_id && record.branch_id !== context.branch_id) {
    throw new HttpError('errors.handover.not_found', 404);
  }

  return record;
};

const buildListWhere = async (filters = {}, context = {}) => {
  const scoped = await resolveListScopedIdentifiers({ filters, context });
  if ((filters.facility_id !== undefined && scoped.facility_id === null) || (filters.branch_id !== undefined && scoped.branch_id === null)) {
    return null;
  }

  const where = {
    tenant_id: scoped.tenant_id,
  };

  if (scoped.facility_id) where.facility_id = scoped.facility_id;
  if (scoped.branch_id) where.branch_id = scoped.branch_id;

  if (filters.office_context_id !== undefined) {
    const officeContextId = await resolveIdentifierForFilter({
      value: filters.office_context_id,
      model: 'office_context',
      where: { tenant_id: scoped.tenant_id },
    });
    if (officeContextId === null) return null;
    if (officeContextId !== undefined) where.office_context_id = officeContextId;
  }

  if (filters.from_user_id !== undefined) {
    const fromUserId = await resolveIdentifierForFilter({
      value: filters.from_user_id,
      model: 'user',
      where: { tenant_id: scoped.tenant_id },
    });
    if (fromUserId === null) return null;
    if (fromUserId !== undefined) where.from_user_id = fromUserId;
  }

  if (filters.to_user_id !== undefined) {
    const toUserId = await resolveIdentifierForFilter({
      value: filters.to_user_id,
      model: 'user',
      where: { tenant_id: scoped.tenant_id },
    });
    if (toUserId === null) return null;
    if (toUserId !== undefined) where.to_user_id = toUserId;
  }

  if (normalizeString(filters.status)) {
    where.status = normalizeString(filters.status).toUpperCase();
  }

  return where;
};

const resolveOfficeContext = async (data = {}, context = {}) => {
  if (data.office_context_id) {
    const officeContextId = await resolveIdentifierForPayload({
      value: data.office_context_id,
      field: 'office_context_id',
      model: 'office_context',
      where: { tenant_id: context.tenant_id },
    });
    const officeContext = await officeContextRepository.findById(officeContextId);
    if (!officeContext) {
      throw new HttpError('errors.office_context.not_found', 404);
    }
    return officeContext;
  }

  const currentOfficeContext = await officeContextRepository.findCurrent({
    tenant_id: context.tenant_id,
    ...(context.facility_id ? { facility_id: context.facility_id } : {}),
    ...(context.branch_id ? { branch_id: context.branch_id } : {}),
  });

  if (!currentOfficeContext) {
    throw new HttpError('errors.office_context.not_found', 404);
  }

  return currentOfficeContext;
};

const listHandovers = async (filters = {}, page = 1, limit = 20, sortBy, order, context = {}) => {
  const where = await buildListWhere(filters, context);
  if (where === null) {
    return {
      handovers: [],
      pagination: buildPagination(page, limit, 0),
    };
  }

  const skip = (page - 1) * limit;
  const orderBy = { [SORT_FIELDS.has(sortBy) ? sortBy : 'created_at']: String(order || '').toLowerCase() === 'asc' ? 'asc' : 'desc' };

  const [records, total] = await Promise.all([
    handoverRepository.findMany(where, skip, limit, orderBy),
    handoverRepository.count(where),
  ]);

  return {
    handovers: records.map(serializeHandover),
    pagination: buildPagination(page, limit, total),
  };
};

const getHandoverById = async (id, context = {}) => {
  const resolvedId = await resolveHandoverId(id);
  const record = ensureScopedRecord(await handoverRepository.findById(resolvedId), context);
  return serializeHandover(record);
};

const createHandover = async (data = {}, context = {}) => {
  const scoped = await resolveScopedIdentifiers({ payload: data, context });
  const officeContext = ensureScopedRecord(await resolveOfficeContext(data, scoped), scoped);
  const fromUserId = await resolveIdentifierForPayload({
    value: data.from_user_id ?? context.user_id,
    field: 'from_user_id',
    model: 'user',
    where: { tenant_id: scoped.tenant_id },
  });
  const toUserId = await resolveIdentifierForPayload({
    value: data.to_user_id,
    field: 'to_user_id',
    model: 'user',
    where: { tenant_id: scoped.tenant_id },
  });

  if (fromUserId === toUserId) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'to_user_id' }]);
  }

  const pendingExisting = await handoverRepository.findMany({
    office_context_id: officeContext.id,
    status: 'PENDING',
  }, 0, 1);

  if (pendingExisting.length > 0) {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'office_context_id' }]);
  }

  const publicId = createPublicId('HND');
  const payload = {
    human_friendly_id: publicId,
    tenant_id: scoped.tenant_id,
    facility_id: officeContext.facility_id,
    branch_id: officeContext.branch_id,
    office_context_id: officeContext.id,
    from_user_id: fromUserId,
    to_user_id: toUserId,
    status: 'PENDING',
    items_json: data.items_json || null,
    signoff_notes: normalizeString(data.signoff_notes) || null,
    accepted_notes: null,
    submitted_at: new Date(),
    etag: buildRecordEtag(publicId, '1', 'PENDING'),
  };

  const record = await handoverRepository.create(payload);
  await officeContextRepository.update(officeContext.id, {
    status: 'HANDOVER_PENDING',
    current_holder_user_id: fromUserId,
    version: Number(officeContext.version || 1) + 1,
    etag: buildRecordEtag(officeContext.human_friendly_id || officeContext.id, String(Number(officeContext.version || 1) + 1), 'HANDOVER_PENDING'),
  });

  const serialized = serializeHandover(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'handover',
    entity_id: record.id,
    diff: { after: serialized },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  recordWorkflowEvent('last_office.handover_created', {
    'hms.handover.id': serialized.id,
    'hms.office_context.id': serialized.office_context_id,
  });

  return serialized;
};

const updateHandover = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveHandoverId(id);
  const current = ensureScopedRecord(await handoverRepository.findById(resolvedId), context);
  const permissions = getUserPermissions(context.user || context);

  if (current.status !== 'PENDING') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  if (current.from_user_id !== context.user_id && !permissions.includes(PERMISSIONS.LAST_OFFICE_APPROVE)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const updateData = {
    version: nextVersion,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), 'PENDING'),
  };

  if (data.items_json !== undefined) updateData.items_json = data.items_json || null;
  if (data.signoff_notes !== undefined) updateData.signoff_notes = normalizeString(data.signoff_notes) || null;
  if (data.to_user_id !== undefined) {
    updateData.to_user_id = await resolveIdentifierForPayload({
      value: data.to_user_id,
      field: 'to_user_id',
      model: 'user',
      where: { tenant_id: current.tenant_id },
    });
  }

  const record = await handoverRepository.update(current.id, updateData);
  const before = serializeHandover(current);
  const after = serializeHandover(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'handover',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return after;
};

const acceptHandover = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveHandoverId(id);
  const current = ensureScopedRecord(await handoverRepository.findById(resolvedId), context);
  const permissions = getUserPermissions(context.user || context);

  if (current.status !== 'PENDING') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  if (current.to_user_id !== context.user_id && !permissions.includes(PERMISSIONS.LAST_OFFICE_APPROVE)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const record = await handoverRepository.update(current.id, {
    status: 'ACCEPTED',
    accepted_notes: normalizeString(data.accepted_notes) || null,
    accepted_at: new Date(),
    version: nextVersion,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), 'ACCEPTED'),
  });

  const officeContext = await officeContextRepository.findById(current.office_context_id);
  if (officeContext) {
    await officeContextRepository.update(officeContext.id, {
      status: 'OPEN',
      current_holder_user_id: record.to_user_id,
      version: Number(officeContext.version || 1) + 1,
      etag: buildRecordEtag(officeContext.human_friendly_id || officeContext.id, String(Number(officeContext.version || 1) + 1), 'OPEN'),
    });
  }

  const before = serializeHandover(current);
  const after = serializeHandover(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'handover',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  await emitLastOfficeEvent({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    event: LAST_OFFICE_EVENTS.LAST_OFFICE_HANDOVER_ACCEPTED,
    payload: {
      handover_id: after.id,
      office_context_id: after.office_context_id,
      to_user_id: after.to_user_id,
    },
  });

  recordWorkflowEvent('last_office.handover_accepted', {
    'hms.handover.id': after.id,
    'hms.office_context.id': after.office_context_id,
  });

  return after;
};

module.exports = {
  acceptHandover,
  createHandover,
  getHandoverById,
  listHandovers,
  updateHandover,
};
