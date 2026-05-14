const shiftCloseRepository = require('@repositories/shift-close/shift-close.repository');
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
  serializeShiftClose,
} = require('@lib/last-office/shared');
const { recordWorkflowEvent } = require('@lib/telemetry/metrics');
const { getUserPermissions } = require('@middlewares/auth.middleware');

const SORT_FIELDS = new Set(['created_at', 'updated_at', 'submitted_at', 'approved_at']);

const resolveShiftCloseId = async (identifier) => {
  const resolved = await resolveModelIdByIdentifier({
    model: 'shift_close',
    identifier,
  });

  return resolved || identifier;
};

const ensureScopedRecord = (record, context = {}) => {
  if (!record || record.deleted_at) {
    throw new HttpError('errors.shift_close.not_found', 404);
  }

  if (context.tenant_id && record.tenant_id !== context.tenant_id) {
    throw new HttpError('errors.shift_close.not_found', 404);
  }

  if (context.facility_id && record.facility_id && record.facility_id !== context.facility_id) {
    throw new HttpError('errors.shift_close.not_found', 404);
  }

  if (context.branch_id && record.branch_id && record.branch_id !== context.branch_id) {
    throw new HttpError('errors.shift_close.not_found', 404);
  }

  return record;
};

const toDecimalString = (value, field) => {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }
  return numberValue.toFixed(2);
};

const toNumber = (value) => {
  if (value === undefined || value === null || value === '') return null;
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
};

const calculateAmounts = (data = {}, current = {}) => {
  const expected = toDecimalString(
    data.expected_amount !== undefined ? data.expected_amount : current.expected_amount,
    'expected_amount'
  );
  const actual = toDecimalString(
    data.actual_amount !== undefined ? data.actual_amount : current.actual_amount,
    'actual_amount'
  );
  const expectedNumber = toNumber(expected);
  const actualNumber = toNumber(actual);
  const variance = expectedNumber !== null && actualNumber !== null
    ? (actualNumber - expectedNumber).toFixed(2)
    : current.variance_amount !== undefined
      ? String(current.variance_amount)
      : null;

  return {
    expected_amount: expected,
    actual_amount: actual,
    variance_amount: variance,
  };
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

  if (filters.shift_id !== undefined) {
    const shiftId = await resolveIdentifierForFilter({
      value: filters.shift_id,
      model: 'shift',
      where: { tenant_id: scoped.tenant_id },
    });
    if (shiftId === null) return null;
    if (shiftId !== undefined) where.shift_id = shiftId;
  }

  if (filters.closed_by_user_id !== undefined) {
    const closedByUserId = await resolveIdentifierForFilter({
      value: filters.closed_by_user_id,
      model: 'user',
      where: { tenant_id: scoped.tenant_id },
    });
    if (closedByUserId === null) return null;
    if (closedByUserId !== undefined) where.closed_by_user_id = closedByUserId;
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

const listShiftCloses = async (filters = {}, page = 1, limit = 20, sortBy, order, context = {}) => {
  const where = await buildListWhere(filters, context);
  if (where === null) {
    return {
      shiftCloses: [],
      pagination: buildPagination(page, limit, 0),
    };
  }

  const skip = (page - 1) * limit;
  const orderBy = { [SORT_FIELDS.has(sortBy) ? sortBy : 'created_at']: String(order || '').toLowerCase() === 'asc' ? 'asc' : 'desc' };

  const [records, total] = await Promise.all([
    shiftCloseRepository.findMany(where, skip, limit, orderBy),
    shiftCloseRepository.count(where),
  ]);

  return {
    shiftCloses: records.map(serializeShiftClose),
    pagination: buildPagination(page, limit, total),
  };
};

const getShiftCloseById = async (id, context = {}) => {
  const resolvedId = await resolveShiftCloseId(id);
  const record = ensureScopedRecord(await shiftCloseRepository.findById(resolvedId), context);
  return serializeShiftClose(record);
};

const createShiftClose = async (data = {}, context = {}) => {
  const scoped = await resolveScopedIdentifiers({ payload: data, context });
  const officeContext = ensureScopedRecord(await resolveOfficeContext(data, scoped), scoped);
  const shiftId = await resolveIdentifierForPayload({
    value: data.shift_id ?? officeContext.shift_id,
    field: 'shift_id',
    model: 'shift',
    where: { tenant_id: scoped.tenant_id },
  });
  const existingDrafts = await shiftCloseRepository.findMany({
    office_context_id: officeContext.id,
    closed_by_user_id: context.user_id,
    shift_id: shiftId,
    status: { in: ['DRAFT', 'SUBMITTED'] },
  }, 0, 1);

  if (existingDrafts.length > 0) {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'office_context_id' }]);
  }

  const nextStatus = data.submit === true || normalizeString(data.status).toUpperCase() === 'SUBMITTED'
    ? 'SUBMITTED'
    : 'DRAFT';
  const amounts = calculateAmounts(data);
  const publicId = createPublicId('SCL');
  const payload = {
    human_friendly_id: publicId,
    tenant_id: scoped.tenant_id,
    facility_id: officeContext.facility_id,
    branch_id: officeContext.branch_id,
    office_context_id: officeContext.id,
    shift_id: shiftId,
    closed_by_user_id: context.user_id,
    status: nextStatus,
    totals_json: data.totals_json || null,
    reconciliation_json: data.reconciliation_json || null,
    expected_amount: amounts.expected_amount,
    actual_amount: amounts.actual_amount,
    variance_amount: amounts.variance_amount,
    submitted_at: nextStatus === 'SUBMITTED' ? new Date() : null,
    notes: normalizeString(data.notes) || null,
    evidence_json: data.evidence_json || null,
    etag: buildRecordEtag(publicId, '1', nextStatus),
  };

  const record = await shiftCloseRepository.create(payload);
  const serialized = serializeShiftClose(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'shift_close',
    entity_id: record.id,
    diff: { after: serialized },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  if (record.status === 'SUBMITTED') {
    await emitLastOfficeEvent({
      tenant_id: record.tenant_id,
      facility_id: record.facility_id,
      event: LAST_OFFICE_EVENTS.LAST_OFFICE_SHIFT_CLOSE_SUBMITTED,
      payload: {
        shift_close_id: serialized.id,
        office_context_id: serialized.office_context_id,
        status: serialized.status,
        variance_amount: serialized.variance_amount,
      },
    });
    recordWorkflowEvent('last_office.shift_close_submitted', {
      'hms.shift_close.id': serialized.id,
      'hms.office_context.id': serialized.office_context_id,
    });
  }

  return serialized;
};

const updateShiftClose = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveShiftCloseId(id);
  const current = ensureScopedRecord(await shiftCloseRepository.findById(resolvedId), context);
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
  const amounts = calculateAmounts(data, current);
  const updateData = {
    version: nextVersion,
    status: nextStatus,
    expected_amount: amounts.expected_amount,
    actual_amount: amounts.actual_amount,
    variance_amount: amounts.variance_amount,
    submitted_at: nextStatus === 'SUBMITTED' ? current.submitted_at || new Date() : null,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), nextStatus),
  };

  if (data.totals_json !== undefined) updateData.totals_json = data.totals_json || null;
  if (data.reconciliation_json !== undefined) updateData.reconciliation_json = data.reconciliation_json || null;
  if (data.notes !== undefined) updateData.notes = normalizeString(data.notes) || null;
  if (data.evidence_json !== undefined) updateData.evidence_json = data.evidence_json || null;

  const record = await shiftCloseRepository.update(current.id, updateData);
  const before = serializeShiftClose(current);
  const after = serializeShiftClose(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'shift_close',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  if (current.status !== 'SUBMITTED' && record.status === 'SUBMITTED') {
    await emitLastOfficeEvent({
      tenant_id: record.tenant_id,
      facility_id: record.facility_id,
      event: LAST_OFFICE_EVENTS.LAST_OFFICE_SHIFT_CLOSE_SUBMITTED,
      payload: {
        shift_close_id: after.id,
        office_context_id: after.office_context_id,
        status: after.status,
        variance_amount: after.variance_amount,
      },
    });
    recordWorkflowEvent('last_office.shift_close_submitted', {
      'hms.shift_close.id': after.id,
      'hms.office_context.id': after.office_context_id,
    });
  }

  return after;
};

const approveShiftClose = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveShiftCloseId(id);
  const current = ensureScopedRecord(await shiftCloseRepository.findById(resolvedId), context);
  const permissions = getUserPermissions(context.user || context);

  if (!permissions.includes(PERMISSIONS.LAST_OFFICE_APPROVE) && !permissions.includes(PERMISSIONS.FINANCIAL_APPROVE)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  if (current.status !== 'SUBMITTED') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const record = await shiftCloseRepository.update(current.id, {
    status: 'APPROVED',
    approved_by_user_id: context.user_id,
    approved_at: new Date(),
    notes: data.notes !== undefined ? normalizeString(data.notes) || null : current.notes,
    version: nextVersion,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), 'APPROVED'),
  });

  const before = serializeShiftClose(current);
  const after = serializeShiftClose(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'shift_close',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  await emitLastOfficeEvent({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    event: LAST_OFFICE_EVENTS.LAST_OFFICE_SHIFT_CLOSE_APPROVED,
    payload: {
      shift_close_id: after.id,
      office_context_id: after.office_context_id,
      approved_by_user_id: after.approved_by_user_id,
      variance_amount: after.variance_amount,
    },
  });

  recordWorkflowEvent('last_office.shift_close_approved', {
    'hms.shift_close.id': after.id,
    'hms.office_context.id': after.office_context_id,
  });

  return after;
};

module.exports = {
  approveShiftClose,
  createShiftClose,
  getShiftCloseById,
  listShiftCloses,
  updateShiftClose,
};
