const officeContextRepository = require('@repositories/office-context/office-context.repository');
const shiftCloseRepository = require('@repositories/shift-close/shift-close.repository');
const dayCloseRepository = require('@repositories/day-close/day-close.repository');
const handoverRepository = require('@repositories/handover/handover.repository');
const { resolveIdentifierForFilter, resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { createAuditLog } = require('@lib/audit');
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
  serializeOfficeContext,
} = require('@lib/last-office/shared');
const { recordWorkflowEvent } = require('@lib/telemetry/metrics');

const SORT_FIELDS = new Set(['created_at', 'updated_at', 'opened_at', 'closed_at', 'office_date']);

const parseDateValue = (value, field, { nullable = true } = {}) => {
  if (value === undefined) return undefined;
  if (value === null) {
    if (nullable) return null;
    throw new HttpError('errors.validation.field.required', 400, [{ field }]);
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }
  return parsed;
};

const resolveOfficeContextId = async (identifier) => {
  const resolved = await resolveModelIdByIdentifier({
    model: 'office_context',
    identifier,
  });

  return resolved || identifier;
};

const ensureScopedRecord = (record, context = {}) => {
  if (!record || record.deleted_at) {
    throw new HttpError('errors.office_context.not_found', 404);
  }

  if (context.tenant_id && record.tenant_id !== context.tenant_id) {
    throw new HttpError('errors.office_context.not_found', 404);
  }

  if (context.facility_id && record.facility_id && record.facility_id !== context.facility_id) {
    throw new HttpError('errors.office_context.not_found', 404);
  }

  if (context.branch_id && record.branch_id && record.branch_id !== context.branch_id) {
    throw new HttpError('errors.office_context.not_found', 404);
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

  if (filters.shift_id !== undefined) {
    const shiftId = await resolveIdentifierForFilter({
      value: filters.shift_id,
      model: 'shift',
      where: { tenant_id: scoped.tenant_id },
    });

    if (shiftId === null) return null;
    if (shiftId !== undefined) where.shift_id = shiftId;
  }

  if (filters.current_holder_user_id !== undefined) {
    const currentHolderUserId = await resolveIdentifierForFilter({
      value: filters.current_holder_user_id,
      model: 'user',
      where: { tenant_id: scoped.tenant_id },
    });

    if (currentHolderUserId === null) return null;
    if (currentHolderUserId !== undefined) where.current_holder_user_id = currentHolderUserId;
  }

  if (normalizeString(filters.status)) {
    where.status = normalizeString(filters.status).toUpperCase();
  }

  if (normalizeString(filters.office_date)) {
    const officeDate = parseDateValue(filters.office_date, 'office_date', { nullable: false });
    const dayStart = new Date(officeDate);
    dayStart.setUTCHours(0, 0, 0, 0);
    const dayEnd = new Date(officeDate);
    dayEnd.setUTCHours(23, 59, 59, 999);
    where.office_date = { gte: dayStart, lte: dayEnd };
  }

  return where;
};

const listOfficeContexts = async (filters = {}, page = 1, limit = 20, sortBy, order, context = {}) => {
  const where = await buildListWhere(filters, context);
  if (where === null) {
    return {
      officeContexts: [],
      pagination: buildPagination(page, limit, 0),
    };
  }

  const skip = (page - 1) * limit;
  const orderBy = { [SORT_FIELDS.has(sortBy) ? sortBy : 'opened_at']: String(order || '').toLowerCase() === 'asc' ? 'asc' : 'desc' };

  const [records, total] = await Promise.all([
    officeContextRepository.findMany(where, skip, limit, orderBy),
    officeContextRepository.count(where),
  ]);

  return {
    officeContexts: records.map(serializeOfficeContext),
    pagination: buildPagination(page, limit, total),
  };
};

const getOfficeContextById = async (id, context = {}) => {
  const resolvedId = await resolveOfficeContextId(id);
  const record = ensureScopedRecord(await officeContextRepository.findById(resolvedId), context);
  return serializeOfficeContext(record);
};

const getCurrentOfficeContext = async (filters = {}, context = {}) => {
  const scoped = await resolveScopedIdentifiers({ payload: filters, context });
  const shiftId = await resolveIdentifierForPayload({
    value: filters.shift_id,
    field: 'shift_id',
    model: 'shift',
    nullable: true,
    where: { tenant_id: scoped.tenant_id },
  });

  const record = await officeContextRepository.findCurrent({
    tenant_id: scoped.tenant_id,
    ...(scoped.facility_id ? { facility_id: scoped.facility_id } : {}),
    ...(scoped.branch_id ? { branch_id: scoped.branch_id } : {}),
    ...(shiftId ? { shift_id: shiftId } : {}),
  });

  if (!record) {
    throw new HttpError('errors.office_context.not_found', 404);
  }

  return serializeOfficeContext(ensureScopedRecord(record, context));
};

const createOfficeContext = async (data = {}, context = {}) => {
  const scoped = await resolveScopedIdentifiers({ payload: data, context });
  const shiftId = await resolveIdentifierForPayload({
    value: data.shift_id,
    field: 'shift_id',
    model: 'shift',
    where: { tenant_id: scoped.tenant_id },
  });
  const currentHolderUserId = await resolveIdentifierForPayload({
    value: data.current_holder_user_id ?? context.user_id,
    field: 'current_holder_user_id',
    model: 'user',
    nullable: true,
    where: { tenant_id: scoped.tenant_id },
  });
  const officeDate = parseDateValue(data.office_date || new Date(), 'office_date', { nullable: false });
  const existing = await officeContextRepository.findCurrent({
    tenant_id: scoped.tenant_id,
    ...(scoped.facility_id ? { facility_id: scoped.facility_id } : {}),
    ...(scoped.branch_id ? { branch_id: scoped.branch_id } : {}),
    shift_id: shiftId,
  });

  if (existing) {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'shift_id' }]);
  }

  const publicId = createPublicId('OFC');
  const payload = {
    human_friendly_id: publicId,
    tenant_id: scoped.tenant_id,
    facility_id: scoped.facility_id,
    branch_id: scoped.branch_id,
    shift_id: shiftId,
    opened_by_user_id: context.user_id,
    current_holder_user_id: currentHolderUserId,
    office_date: officeDate,
    status: 'OPEN',
    handover_due_at: parseDateValue(data.handover_due_at, 'handover_due_at'),
    notes: normalizeString(data.notes) || null,
    metadata_json: data.metadata_json || null,
    etag: buildRecordEtag(publicId, '1', 'OPEN'),
  };

  const record = await officeContextRepository.create(payload);
  const serialized = serializeOfficeContext(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'office_context',
    entity_id: record.id,
    diff: { after: serialized },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  await emitLastOfficeEvent({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    event: LAST_OFFICE_EVENTS.LAST_OFFICE_OFFICE_CONTEXT_OPENED,
    payload: {
      office_context_id: serialized.id,
      branch_id: serialized.branch_id,
      shift_id: serialized.shift_id,
      status: serialized.status,
    },
  });

  recordWorkflowEvent('last_office.office_context_opened', {
    'hms.office_context.id': serialized.id,
    'hms.facility.id': serialized.facility_id,
  });

  return serialized;
};

const updateOfficeContext = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveOfficeContextId(id);
  const current = ensureScopedRecord(await officeContextRepository.findById(resolvedId), context);
  if (current.status === 'CLOSED') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const updateData = {
    version: nextVersion,
  };

  if (data.current_holder_user_id !== undefined) {
    updateData.current_holder_user_id = await resolveIdentifierForPayload({
      value: data.current_holder_user_id,
      field: 'current_holder_user_id',
      model: 'user',
      nullable: true,
      where: { tenant_id: current.tenant_id },
    });
  }
  if (data.office_date !== undefined) updateData.office_date = parseDateValue(data.office_date, 'office_date', { nullable: false });
  if (data.handover_due_at !== undefined) updateData.handover_due_at = parseDateValue(data.handover_due_at, 'handover_due_at');
  if (data.notes !== undefined) updateData.notes = normalizeString(data.notes) || null;
  if (data.metadata_json !== undefined) updateData.metadata_json = data.metadata_json || null;
  if (data.status !== undefined) {
    const nextStatus = normalizeString(data.status).toUpperCase();
    if (!['OPEN', 'HANDOVER_PENDING'].includes(nextStatus)) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'status' }]);
    }
    updateData.status = nextStatus;
  }

  updateData.etag = buildRecordEtag(
    current.human_friendly_id || current.id,
    String(nextVersion),
    updateData.status || current.status
  );

  const record = await officeContextRepository.update(current.id, updateData);
  const before = serializeOfficeContext(current);
  const after = serializeOfficeContext(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'office_context',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return after;
};

const closeOfficeContext = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveOfficeContextId(id);
  const current = ensureScopedRecord(await officeContextRepository.findById(resolvedId), context);
  if (current.status === 'CLOSED') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  const [pendingShiftCloses, pendingDayCloses, pendingHandovers] = await Promise.all([
    shiftCloseRepository.count({
      office_context_id: current.id,
      status: { in: ['DRAFT', 'SUBMITTED'] },
    }),
    dayCloseRepository.count({
      office_context_id: current.id,
      status: { in: ['DRAFT', 'SUBMITTED'] },
    }),
    handoverRepository.count({
      office_context_id: current.id,
      status: 'PENDING',
    }),
  ]);

  if (pendingShiftCloses || pendingDayCloses || pendingHandovers) {
    throw new HttpError('errors.validation.invalid', 409, [
      { field: 'office_context', message: 'Pending Last Office records must be completed before close.' },
    ]);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const nextNotes = [normalizeString(current.notes), normalizeString(data.notes)]
    .filter(Boolean)
    .join('\n\n') || null;

  const record = await officeContextRepository.update(current.id, {
    status: 'CLOSED',
    closed_at: new Date(),
    current_holder_user_id: null,
    notes: nextNotes,
    version: nextVersion,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), 'CLOSED'),
  });

  const before = serializeOfficeContext(current);
  const after = serializeOfficeContext(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'office_context',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  recordWorkflowEvent('last_office.office_context_closed', {
    'hms.office_context.id': after.id,
    'hms.facility.id': after.facility_id,
  });

  return after;
};

module.exports = {
  closeOfficeContext,
  createOfficeContext,
  getCurrentOfficeContext,
  getOfficeContextById,
  listOfficeContexts,
  updateOfficeContext,
};
