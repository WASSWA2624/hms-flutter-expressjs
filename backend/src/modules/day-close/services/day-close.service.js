const dayCloseRepository = require('@repositories/day-close/day-close.repository');
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
  serializeDayClose,
} = require('@lib/last-office/shared');
const { recordWorkflowEvent } = require('@lib/telemetry/metrics');
const { getUserPermissions } = require('@middlewares/auth.middleware');

const SORT_FIELDS = new Set(['created_at', 'updated_at', 'submitted_at', 'approved_at']);

const resolveDayCloseId = async (identifier) => {
  const resolved = await resolveModelIdByIdentifier({
    model: 'day_close',
    identifier,
  });

  return resolved || identifier;
};

const ensureScopedRecord = (record, context = {}) => {
  if (!record || record.deleted_at) {
    throw new HttpError('errors.day_close.not_found', 404);
  }

  if (context.tenant_id && record.tenant_id !== context.tenant_id) {
    throw new HttpError('errors.day_close.not_found', 404);
  }

  if (context.facility_id && record.facility_id && record.facility_id !== context.facility_id) {
    throw new HttpError('errors.day_close.not_found', 404);
  }

  if (context.branch_id && record.branch_id && record.branch_id !== context.branch_id) {
    throw new HttpError('errors.day_close.not_found', 404);
  }

  return record;
};

const hasBlockingItems = (value) => {
  if (!value) return false;
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === 'object') return Object.keys(value).length > 0;
  return Boolean(String(value).trim());
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

  if (filters.submitted_by_user_id !== undefined) {
    const submittedByUserId = await resolveIdentifierForFilter({
      value: filters.submitted_by_user_id,
      model: 'user',
      where: { tenant_id: scoped.tenant_id },
    });
    if (submittedByUserId === null) return null;
    if (submittedByUserId !== undefined) where.submitted_by_user_id = submittedByUserId;
  }

  if (filters.approved_by_user_id !== undefined) {
    const approvedByUserId = await resolveIdentifierForFilter({
      value: filters.approved_by_user_id,
      model: 'user',
      where: { tenant_id: scoped.tenant_id },
    });
    if (approvedByUserId === null) return null;
    if (approvedByUserId !== undefined) where.approved_by_user_id = approvedByUserId;
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

const listDayCloses = async (filters = {}, page = 1, limit = 20, sortBy, order, context = {}) => {
  const where = await buildListWhere(filters, context);
  if (where === null) {
    return {
      dayCloses: [],
      pagination: buildPagination(page, limit, 0),
    };
  }

  const skip = (page - 1) * limit;
  const orderBy = { [SORT_FIELDS.has(sortBy) ? sortBy : 'created_at']: String(order || '').toLowerCase() === 'asc' ? 'asc' : 'desc' };

  const [records, total] = await Promise.all([
    dayCloseRepository.findMany(where, skip, limit, orderBy),
    dayCloseRepository.count(where),
  ]);

  return {
    dayCloses: records.map(serializeDayClose),
    pagination: buildPagination(page, limit, total),
  };
};

const getDayCloseById = async (id, context = {}) => {
  const resolvedId = await resolveDayCloseId(id);
  const record = ensureScopedRecord(await dayCloseRepository.findById(resolvedId), context);
  return serializeDayClose(record);
};

const createDayClose = async (data = {}, context = {}) => {
  const scoped = await resolveScopedIdentifiers({ payload: data, context });
  const officeContext = ensureScopedRecord(await resolveOfficeContext(data, scoped), scoped);
  const existingDrafts = await dayCloseRepository.findMany({
    office_context_id: officeContext.id,
    submitted_by_user_id: context.user_id,
    status: { in: ['DRAFT', 'SUBMITTED'] },
  }, 0, 1);

  if (existingDrafts.length > 0) {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'office_context_id' }]);
  }

  const nextStatus = data.submit === true || normalizeString(data.status).toUpperCase() === 'SUBMITTED'
    ? 'SUBMITTED'
    : 'DRAFT';
  const publicId = createPublicId('DCL');
  const payload = {
    human_friendly_id: publicId,
    tenant_id: scoped.tenant_id,
    facility_id: officeContext.facility_id,
    branch_id: officeContext.branch_id,
    office_context_id: officeContext.id,
    submitted_by_user_id: context.user_id,
    status: nextStatus,
    checklist_json: data.checklist_json || null,
    blockers_json: data.blockers_json || null,
    unresolved_items_json: data.unresolved_items_json || null,
    submitted_at: nextStatus === 'SUBMITTED' ? new Date() : null,
    notes: normalizeString(data.notes) || null,
    evidence_json: data.evidence_json || null,
    etag: buildRecordEtag(publicId, '1', nextStatus),
  };

  const record = await dayCloseRepository.create(payload);
  const serialized = serializeDayClose(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'day_close',
    entity_id: record.id,
    diff: { after: serialized },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  if (record.status === 'SUBMITTED') {
    await emitLastOfficeEvent({
      tenant_id: record.tenant_id,
      facility_id: record.facility_id,
      event: LAST_OFFICE_EVENTS.LAST_OFFICE_DAY_CLOSE_SUBMITTED,
      payload: {
        day_close_id: serialized.id,
        office_context_id: serialized.office_context_id,
        status: serialized.status,
      },
    });
    recordWorkflowEvent('last_office.day_close_submitted', {
      'hms.day_close.id': serialized.id,
      'hms.office_context.id': serialized.office_context_id,
    });
  }

  return serialized;
};

const updateDayClose = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveDayCloseId(id);
  const current = ensureScopedRecord(await dayCloseRepository.findById(resolvedId), context);
  if (current.status === 'APPROVED') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  const nextStatus = data.submit === true
    ? 'SUBMITTED'
    : data.status !== undefined
      ? normalizeString(data.status).toUpperCase()
      : current.status;

  if (!['DRAFT', 'SUBMITTED'].includes(nextStatus)) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'status' }]);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const updateData = {
    version: nextVersion,
    status: nextStatus,
    submitted_at: nextStatus === 'SUBMITTED' ? current.submitted_at || new Date() : null,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), nextStatus),
  };

  if (data.checklist_json !== undefined) updateData.checklist_json = data.checklist_json || null;
  if (data.blockers_json !== undefined) updateData.blockers_json = data.blockers_json || null;
  if (data.unresolved_items_json !== undefined) updateData.unresolved_items_json = data.unresolved_items_json || null;
  if (data.notes !== undefined) updateData.notes = normalizeString(data.notes) || null;
  if (data.evidence_json !== undefined) updateData.evidence_json = data.evidence_json || null;

  const record = await dayCloseRepository.update(current.id, updateData);
  const before = serializeDayClose(current);
  const after = serializeDayClose(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'day_close',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  if (current.status !== 'SUBMITTED' && record.status === 'SUBMITTED') {
    await emitLastOfficeEvent({
      tenant_id: record.tenant_id,
      facility_id: record.facility_id,
      event: LAST_OFFICE_EVENTS.LAST_OFFICE_DAY_CLOSE_SUBMITTED,
      payload: {
        day_close_id: after.id,
        office_context_id: after.office_context_id,
        status: after.status,
      },
    });
    recordWorkflowEvent('last_office.day_close_submitted', {
      'hms.day_close.id': after.id,
      'hms.office_context.id': after.office_context_id,
    });
  }

  return after;
};

const approveDayClose = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveDayCloseId(id);
  const current = ensureScopedRecord(await dayCloseRepository.findById(resolvedId), context);
  const permissions = getUserPermissions(context.user || context);

  if (!permissions.includes(PERMISSIONS.LAST_OFFICE_APPROVE)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  if (current.status !== 'SUBMITTED') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  const blockers = data.blockers_json !== undefined ? data.blockers_json : current.blockers_json;
  if (hasBlockingItems(blockers)) {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'blockers_json' }]);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const record = await dayCloseRepository.update(current.id, {
    status: 'APPROVED',
    approved_by_user_id: context.user_id,
    approved_at: new Date(),
    blockers_json: blockers || null,
    notes: data.notes !== undefined ? normalizeString(data.notes) || null : current.notes,
    version: nextVersion,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), 'APPROVED'),
  });

  const before = serializeDayClose(current);
  const after = serializeDayClose(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'day_close',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  await emitLastOfficeEvent({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    event: LAST_OFFICE_EVENTS.LAST_OFFICE_DAY_CLOSE_APPROVED,
    payload: {
      day_close_id: after.id,
      office_context_id: after.office_context_id,
      approved_by_user_id: after.approved_by_user_id,
    },
  });

  recordWorkflowEvent('last_office.day_close_approved', {
    'hms.day_close.id': after.id,
    'hms.office_context.id': after.office_context_id,
  });

  return after;
};

module.exports = {
  approveDayClose,
  createDayClose,
  getDayCloseById,
  listDayCloses,
  updateDayClose,
};
