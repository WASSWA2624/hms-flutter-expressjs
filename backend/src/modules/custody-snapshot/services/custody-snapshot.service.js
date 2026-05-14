const custodySnapshotRepository = require('@repositories/custody-snapshot/custody-snapshot.repository');
const officeContextRepository = require('@repositories/office-context/office-context.repository');
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
  serializeCustodySnapshot,
} = require('@lib/last-office/shared');
const { recordWorkflowEvent } = require('@lib/telemetry/metrics');

const SORT_FIELDS = new Set(['created_at', 'updated_at', 'captured_at', 'finalized_at']);

const resolveCustodySnapshotId = async (identifier) => {
  const resolved = await resolveModelIdByIdentifier({
    model: 'custody_snapshot',
    identifier,
  });

  return resolved || identifier;
};

const ensureScopedRecord = (record, context = {}) => {
  if (!record || record.deleted_at) {
    throw new HttpError('errors.custody_snapshot.not_found', 404);
  }

  if (context.tenant_id && record.tenant_id !== context.tenant_id) {
    throw new HttpError('errors.custody_snapshot.not_found', 404);
  }

  if (context.facility_id && record.facility_id && record.facility_id !== context.facility_id) {
    throw new HttpError('errors.custody_snapshot.not_found', 404);
  }

  if (context.branch_id && record.branch_id && record.branch_id !== context.branch_id) {
    throw new HttpError('errors.custody_snapshot.not_found', 404);
  }

  return record;
};

const hasSnapshotEvidence = (record = {}) =>
  Boolean(
    (Array.isArray(record.asset_snapshot_json) && record.asset_snapshot_json.length > 0)
      || (record.asset_snapshot_json && typeof record.asset_snapshot_json === 'object' && Object.keys(record.asset_snapshot_json).length > 0)
      || (Array.isArray(record.cash_drawer_snapshot_json) && record.cash_drawer_snapshot_json.length > 0)
      || (record.cash_drawer_snapshot_json && typeof record.cash_drawer_snapshot_json === 'object' && Object.keys(record.cash_drawer_snapshot_json).length > 0)
      || (Array.isArray(record.controlled_items_json) && record.controlled_items_json.length > 0)
      || (record.controlled_items_json && typeof record.controlled_items_json === 'object' && Object.keys(record.controlled_items_json).length > 0)
  );

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

  if (filters.captured_by_user_id !== undefined) {
    const capturedByUserId = await resolveIdentifierForFilter({
      value: filters.captured_by_user_id,
      model: 'user',
      where: { tenant_id: scoped.tenant_id },
    });
    if (capturedByUserId === null) return null;
    if (capturedByUserId !== undefined) where.captured_by_user_id = capturedByUserId;
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

const listCustodySnapshots = async (filters = {}, page = 1, limit = 20, sortBy, order, context = {}) => {
  const where = await buildListWhere(filters, context);
  if (where === null) {
    return {
      custodySnapshots: [],
      pagination: buildPagination(page, limit, 0),
    };
  }

  const skip = (page - 1) * limit;
  const orderBy = { [SORT_FIELDS.has(sortBy) ? sortBy : 'created_at']: String(order || '').toLowerCase() === 'asc' ? 'asc' : 'desc' };

  const [records, total] = await Promise.all([
    custodySnapshotRepository.findMany(where, skip, limit, orderBy),
    custodySnapshotRepository.count(where),
  ]);

  return {
    custodySnapshots: records.map(serializeCustodySnapshot),
    pagination: buildPagination(page, limit, total),
  };
};

const getCustodySnapshotById = async (id, context = {}) => {
  const resolvedId = await resolveCustodySnapshotId(id);
  const record = ensureScopedRecord(await custodySnapshotRepository.findById(resolvedId), context);
  return serializeCustodySnapshot(record);
};

const createCustodySnapshot = async (data = {}, context = {}) => {
  const scoped = await resolveScopedIdentifiers({ payload: data, context });
  const officeContext = ensureScopedRecord(await resolveOfficeContext(data, scoped), scoped);
  const existingDrafts = await custodySnapshotRepository.findMany({
    office_context_id: officeContext.id,
    captured_by_user_id: context.user_id,
    status: 'DRAFT',
  }, 0, 1);

  if (existingDrafts.length > 0) {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'office_context_id' }]);
  }

  const publicId = createPublicId('CST');
  const payload = {
    human_friendly_id: publicId,
    tenant_id: scoped.tenant_id,
    facility_id: officeContext.facility_id,
    branch_id: officeContext.branch_id,
    office_context_id: officeContext.id,
    captured_by_user_id: context.user_id,
    status: 'DRAFT',
    asset_snapshot_json: data.asset_snapshot_json || null,
    cash_drawer_snapshot_json: data.cash_drawer_snapshot_json || null,
    controlled_items_json: data.controlled_items_json || null,
    captured_at: new Date(),
    notes: normalizeString(data.notes) || null,
    etag: buildRecordEtag(publicId, '1', 'DRAFT'),
  };

  const record = await custodySnapshotRepository.create(payload);
  const serialized = serializeCustodySnapshot(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'custody_snapshot',
    entity_id: record.id,
    diff: { after: serialized },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serialized;
};

const updateCustodySnapshot = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveCustodySnapshotId(id);
  const current = ensureScopedRecord(await custodySnapshotRepository.findById(resolvedId), context);
  if (current.status === 'FINALIZED') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const updateData = {
    version: nextVersion,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), current.status),
  };

  if (data.asset_snapshot_json !== undefined) updateData.asset_snapshot_json = data.asset_snapshot_json || null;
  if (data.cash_drawer_snapshot_json !== undefined) updateData.cash_drawer_snapshot_json = data.cash_drawer_snapshot_json || null;
  if (data.controlled_items_json !== undefined) updateData.controlled_items_json = data.controlled_items_json || null;
  if (data.notes !== undefined) updateData.notes = normalizeString(data.notes) || null;

  const record = await custodySnapshotRepository.update(current.id, updateData);
  const before = serializeCustodySnapshot(current);
  const after = serializeCustodySnapshot(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'custody_snapshot',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return after;
};

const finalizeCustodySnapshot = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveCustodySnapshotId(id);
  const current = ensureScopedRecord(await custodySnapshotRepository.findById(resolvedId), context);
  if (current.status === 'FINALIZED') {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'status' }]);
  }

  const nextRecord = {
    ...current,
    asset_snapshot_json: data.asset_snapshot_json !== undefined ? data.asset_snapshot_json : current.asset_snapshot_json,
    cash_drawer_snapshot_json: data.cash_drawer_snapshot_json !== undefined ? data.cash_drawer_snapshot_json : current.cash_drawer_snapshot_json,
    controlled_items_json: data.controlled_items_json !== undefined ? data.controlled_items_json : current.controlled_items_json,
  };

  if (!hasSnapshotEvidence(nextRecord)) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'asset_snapshot_json' }]);
  }

  const nextVersion = Number(current.version || 1) + 1;
  const record = await custodySnapshotRepository.update(current.id, {
    status: 'FINALIZED',
    asset_snapshot_json: nextRecord.asset_snapshot_json || null,
    cash_drawer_snapshot_json: nextRecord.cash_drawer_snapshot_json || null,
    controlled_items_json: nextRecord.controlled_items_json || null,
    finalized_at: new Date(),
    notes: data.notes !== undefined ? normalizeString(data.notes) || null : current.notes,
    version: nextVersion,
    etag: buildRecordEtag(current.human_friendly_id || current.id, String(nextVersion), 'FINALIZED'),
  });

  const before = serializeCustodySnapshot(current);
  const after = serializeCustodySnapshot(record);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'custody_snapshot',
    entity_id: record.id,
    diff: { before, after },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  await emitLastOfficeEvent({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    event: LAST_OFFICE_EVENTS.LAST_OFFICE_CUSTODY_SNAPSHOT_FINALIZED,
    payload: {
      custody_snapshot_id: after.id,
      office_context_id: after.office_context_id,
      captured_by_user_id: after.captured_by_user_id,
    },
  });

  recordWorkflowEvent('last_office.custody_snapshot_finalized', {
    'hms.custody_snapshot.id': after.id,
    'hms.office_context.id': after.office_context_id,
  });

  return after;
};

module.exports = {
  createCustodySnapshot,
  finalizeCustodySnapshot,
  getCustodySnapshotById,
  listCustodySnapshots,
  updateCustodySnapshot,
};
