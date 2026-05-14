const crypto = require('crypto');
const closeoutPackRepository = require('@repositories/closeout-pack/closeout-pack.repository');
const officeContextRepository = require('@repositories/office-context/office-context.repository');
const shiftCloseRepository = require('@repositories/shift-close/shift-close.repository');
const dayCloseRepository = require('@repositories/day-close/day-close.repository');
const handoverRepository = require('@repositories/handover/handover.repository');
const custodySnapshotRepository = require('@repositories/custody-snapshot/custody-snapshot.repository');
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
  serializeCloseoutPack,
} = require('@lib/last-office/shared');
const { generateReportFile } = require('@lib/reports/files');
const { recordBackgroundJob, recordWorkflowEvent } = require('@lib/telemetry/metrics');
const { createStorageService } = require('@lib/storage');
const { getUserPermissions } = require('@middlewares/auth.middleware');

const SORT_FIELDS = new Set(['created_at', 'updated_at', 'generated_at']);
const SUPPORTED_FORMATS = new Set(['PDF', 'CSV', 'JSON', 'XLSX']);

const resolveCloseoutPackId = async (identifier) => {
  const resolved = await resolveModelIdByIdentifier({
    model: 'closeout_pack',
    identifier,
  });

  return resolved || identifier;
};

const ensureScopedRecord = (record, context = {}) => {
  if (!record || record.deleted_at) {
    throw new HttpError('errors.closeout_pack.not_found', 404);
  }

  if (context.tenant_id && record.tenant_id !== context.tenant_id) {
    throw new HttpError('errors.closeout_pack.not_found', 404);
  }

  if (context.facility_id && record.facility_id && record.facility_id !== context.facility_id) {
    throw new HttpError('errors.closeout_pack.not_found', 404);
  }

  if (context.branch_id && record.branch_id && record.branch_id !== context.branch_id) {
    throw new HttpError('errors.closeout_pack.not_found', 404);
  }

  return record;
};

const buildStoragePath = (tenantId, fileName, createdAt = new Date()) => {
  const year = String(createdAt.getUTCFullYear());
  const month = String(createdAt.getUTCMonth() + 1).padStart(2, '0');
  return `last-office/${tenantId}/${year}/${month}/${fileName}`;
};

const buildSummary = ({ officeContext, shiftClose, dayClose, handover, custodySnapshot }) => ({
  office_context: officeContext ? {
    id: officeContext.human_friendly_id || officeContext.id,
    status: officeContext.status,
    office_date: officeContext.office_date,
    shift_id: officeContext.shift?.human_friendly_id || officeContext.shift_id,
  } : null,
  shift_close: shiftClose ? {
    id: shiftClose.human_friendly_id || shiftClose.id,
    status: shiftClose.status,
    expected_amount: shiftClose.expected_amount ? String(shiftClose.expected_amount) : null,
    actual_amount: shiftClose.actual_amount ? String(shiftClose.actual_amount) : null,
    variance_amount: shiftClose.variance_amount ? String(shiftClose.variance_amount) : null,
    totals_json: shiftClose.totals_json || null,
    reconciliation_json: shiftClose.reconciliation_json || null,
  } : null,
  day_close: dayClose ? {
    id: dayClose.human_friendly_id || dayClose.id,
    status: dayClose.status,
    checklist_json: dayClose.checklist_json || null,
    blockers_json: dayClose.blockers_json || null,
    unresolved_items_json: dayClose.unresolved_items_json || null,
  } : null,
  handover: handover ? {
    id: handover.human_friendly_id || handover.id,
    status: handover.status,
    from_user_id: handover.from_user?.human_friendly_id || handover.from_user_id,
    to_user_id: handover.to_user?.human_friendly_id || handover.to_user_id,
    items_json: handover.items_json || null,
  } : null,
  custody_snapshot: custodySnapshot ? {
    id: custodySnapshot.human_friendly_id || custodySnapshot.id,
    status: custodySnapshot.status,
    asset_snapshot_json: custodySnapshot.asset_snapshot_json || null,
    cash_drawer_snapshot_json: custodySnapshot.cash_drawer_snapshot_json || null,
    controlled_items_json: custodySnapshot.controlled_items_json || null,
  } : null,
});

const buildReportRows = (summary = {}) => {
  const rows = [];

  const pushEntry = (section, key, value) => {
    if (value === undefined || value === null || value === '') return;
    rows.push({
      section,
      field: key,
      value: typeof value === 'object' ? JSON.stringify(value) : String(value),
    });
  };

  Object.entries(summary || {}).forEach(([section, sectionValue]) => {
    if (!sectionValue || typeof sectionValue !== 'object') return;
    Object.entries(sectionValue).forEach(([field, value]) => pushEntry(section, field, value));
  });

  return rows;
};

const normalizeFormat = (value) => {
  const normalized = normalizeString(value).toUpperCase() || 'PDF';
  if (!SUPPORTED_FORMATS.has(normalized)) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'format' }]);
  }
  return normalized;
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

  if (filters.generated_by_user_id !== undefined) {
    const generatedByUserId = await resolveIdentifierForFilter({
      value: filters.generated_by_user_id,
      model: 'user',
      where: { tenant_id: scoped.tenant_id },
    });
    if (generatedByUserId === null) return null;
    if (generatedByUserId !== undefined) where.generated_by_user_id = generatedByUserId;
  }

  if (normalizeString(filters.status)) {
    where.status = normalizeString(filters.status).toUpperCase();
  }

  if (normalizeString(filters.format)) {
    where.format = normalizeFormat(filters.format);
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
    const officeContext = await officeContextRepository.findById(officeContextId, {
      shift: { select: { id: true, human_friendly_id: true } },
      facility: { select: { id: true, human_friendly_id: true } },
      branch: { select: { id: true, human_friendly_id: true } },
    });
    if (!officeContext) {
      throw new HttpError('errors.office_context.not_found', 404);
    }
    return officeContext;
  }

  const currentOfficeContext = await officeContextRepository.findCurrent({
    tenant_id: context.tenant_id,
    ...(context.facility_id ? { facility_id: context.facility_id } : {}),
    ...(context.branch_id ? { branch_id: context.branch_id } : {}),
  }, {
    shift: { select: { id: true, human_friendly_id: true } },
    facility: { select: { id: true, human_friendly_id: true } },
    branch: { select: { id: true, human_friendly_id: true } },
  });

  if (!currentOfficeContext) {
    throw new HttpError('errors.office_context.not_found', 404);
  }

  return currentOfficeContext;
};

const getLatestRecord = async (repository, where = {}, sortField) => {
  const records = await repository.findMany(where, 0, 1, { [sortField]: 'desc' });
  return records[0] || null;
};

const assertTerminalWorkflowState = (record, expectedStatus, field) => {
  if (!record) return;
  if (String(record.status || '').toUpperCase() !== expectedStatus) {
    throw new HttpError('errors.validation.invalid', 409, [{ field }]);
  }
};

const assertEvidencePermission = (context = {}) => {
  const permissions = getUserPermissions(context.user || context);
  if (!permissions.includes(PERMISSIONS.EVIDENCE_EXPORT)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
};

const listCloseoutPacks = async (filters = {}, page = 1, limit = 20, sortBy, order, context = {}) => {
  const where = await buildListWhere(filters, context);
  if (where === null) {
    return {
      closeoutPacks: [],
      pagination: buildPagination(page, limit, 0),
    };
  }

  const skip = (page - 1) * limit;
  const orderBy = { [SORT_FIELDS.has(sortBy) ? sortBy : 'created_at']: String(order || '').toLowerCase() === 'asc' ? 'asc' : 'desc' };

  const [records, total] = await Promise.all([
    closeoutPackRepository.findMany(where, skip, limit, orderBy),
    closeoutPackRepository.count(where),
  ]);

  return {
    closeoutPacks: records.map(serializeCloseoutPack),
    pagination: buildPagination(page, limit, total),
  };
};

const getCloseoutPackById = async (id, context = {}) => {
  const resolvedId = await resolveCloseoutPackId(id);
  const record = ensureScopedRecord(await closeoutPackRepository.findById(resolvedId), context);
  return serializeCloseoutPack(record);
};

const createCloseoutPack = async (data = {}, context = {}) => {
  assertEvidencePermission(context);
  const scoped = await resolveScopedIdentifiers({ payload: data, context });
  const officeContext = ensureScopedRecord(await resolveOfficeContext(data, scoped), scoped);
  const format = normalizeFormat(data.format);
  const publicId = createPublicId('CLP');

  const shiftClose = data.shift_close_id
    ? await shiftCloseRepository.findById(
        await resolveIdentifierForPayload({
          value: data.shift_close_id,
          field: 'shift_close_id',
          model: 'shift_close',
          nullable: true,
          where: { tenant_id: scoped.tenant_id, office_context_id: officeContext.id },
        })
      )
    : await getLatestRecord(shiftCloseRepository, { office_context_id: officeContext.id, status: 'APPROVED' }, 'approved_at');

  const dayClose = data.day_close_id
    ? await dayCloseRepository.findById(
        await resolveIdentifierForPayload({
          value: data.day_close_id,
          field: 'day_close_id',
          model: 'day_close',
          nullable: true,
          where: { tenant_id: scoped.tenant_id, office_context_id: officeContext.id },
        })
      )
    : await getLatestRecord(dayCloseRepository, { office_context_id: officeContext.id, status: 'APPROVED' }, 'approved_at');

  const handover = data.handover_id
    ? await handoverRepository.findById(
        await resolveIdentifierForPayload({
          value: data.handover_id,
          field: 'handover_id',
          model: 'handover',
          nullable: true,
          where: { tenant_id: scoped.tenant_id, office_context_id: officeContext.id },
        })
      )
    : await getLatestRecord(handoverRepository, { office_context_id: officeContext.id, status: 'ACCEPTED' }, 'accepted_at');

  const custodySnapshot = data.custody_snapshot_id
    ? await custodySnapshotRepository.findById(
        await resolveIdentifierForPayload({
          value: data.custody_snapshot_id,
          field: 'custody_snapshot_id',
          model: 'custody_snapshot',
          nullable: true,
          where: { tenant_id: scoped.tenant_id, office_context_id: officeContext.id },
        })
      )
    : await getLatestRecord(custodySnapshotRepository, { office_context_id: officeContext.id, status: 'FINALIZED' }, 'finalized_at');

  assertTerminalWorkflowState(shiftClose, 'APPROVED', 'shift_close_id');
  assertTerminalWorkflowState(dayClose, 'APPROVED', 'day_close_id');
  assertTerminalWorkflowState(handover, 'ACCEPTED', 'handover_id');
  assertTerminalWorkflowState(custodySnapshot, 'FINALIZED', 'custody_snapshot_id');

  const initialRecord = await closeoutPackRepository.create({
    human_friendly_id: publicId,
    tenant_id: scoped.tenant_id,
    facility_id: officeContext.facility_id,
    branch_id: officeContext.branch_id,
    office_context_id: officeContext.id,
    shift_close_id: shiftClose?.id || null,
    day_close_id: dayClose?.id || null,
    handover_id: handover?.id || null,
    custody_snapshot_id: custodySnapshot?.id || null,
    generated_by_user_id: context.user_id,
    status: 'PROCESSING',
    format,
    summary_json: null,
    parameter_overrides_json: data.parameter_overrides_json || null,
    etag: buildRecordEtag(publicId, '1', 'PROCESSING'),
  });

  await createAuditLog({
    tenant_id: initialRecord.tenant_id,
    facility_id: initialRecord.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'closeout_pack',
    entity_id: initialRecord.id,
    diff: { after: serializeCloseoutPack(initialRecord) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  recordBackgroundJob('closeout_pack.started', {
    'hms.closeout_pack.id': publicId,
    'hms.office_context.id': officeContext.human_friendly_id || officeContext.id,
  });

  try {
    const summary = buildSummary({ officeContext, shiftClose, dayClose, handover, custodySnapshot });
    const rows = buildReportRows(summary);
    const rendered = await generateReportFile({
      title: `Closeout Pack ${officeContext.human_friendly_id || officeContext.id}`,
      subtitle: 'Last Office evidence bundle',
      columns: ['section', 'field', 'value'],
      rows,
      format,
    });

    const checksum = crypto.createHash('sha256').update(rendered.buffer).digest('hex');
    const storage = createStorageService();
    const storagePath = buildStoragePath(initialRecord.tenant_id, rendered.file_name, new Date());
    const uploaded = await storage.upload(rendered.buffer, storagePath, {
      mimeType: rendered.mime_type,
      encrypt: true,
      metadata: {
        closeout_pack_id: initialRecord.id,
        office_context_id: officeContext.id,
      },
    });

    const nextVersion = Number(initialRecord.version || 1) + 1;
    const record = await closeoutPackRepository.update(initialRecord.id, {
      status: 'READY',
      output_storage_path: uploaded?.path || storagePath,
      output_file_name: rendered.file_name,
      output_mime_type: rendered.mime_type,
      output_size_bytes: rendered.size_bytes,
      checksum,
      generated_at: new Date(),
      error_message: null,
      summary_json: summary,
      version: nextVersion,
      etag: buildRecordEtag(publicId, String(nextVersion), 'READY'),
    });

    const serialized = serializeCloseoutPack(record);

    await createAuditLog({
      tenant_id: record.tenant_id,
      facility_id: record.facility_id,
      user_id: context.user_id,
      action: 'UPDATE',
      entity: 'closeout_pack',
      entity_id: record.id,
      diff: {
        before: serializeCloseoutPack(initialRecord),
        after: serialized,
      },
      ip_address: context.ip_address,
      user_agent: context.user_agent,
    });

    await emitLastOfficeEvent({
      tenant_id: record.tenant_id,
      facility_id: record.facility_id,
      event: LAST_OFFICE_EVENTS.LAST_OFFICE_CLOSEOUT_PACK_READY,
      payload: {
        closeout_pack_id: serialized.id,
        office_context_id: serialized.office_context_id,
        format: serialized.format,
      },
    });

    recordWorkflowEvent('last_office.closeout_pack_ready', {
      'hms.closeout_pack.id': serialized.id,
      'hms.office_context.id': serialized.office_context_id,
    });
    recordBackgroundJob('closeout_pack.completed', {
      'hms.closeout_pack.id': serialized.id,
      'hms.closeout_pack.format': serialized.format,
    });

    return serialized;
  } catch (error) {
    const nextVersion = Number(initialRecord.version || 1) + 1;
    const failedRecord = await closeoutPackRepository.update(initialRecord.id, {
      status: 'FAILED',
      error_message: String(error?.message || 'Closeout pack generation failed').slice(0, 10000),
      version: nextVersion,
      etag: buildRecordEtag(publicId, String(nextVersion), 'FAILED'),
    });

    await createAuditLog({
      tenant_id: failedRecord.tenant_id,
      facility_id: failedRecord.facility_id,
      user_id: context.user_id,
      action: 'UPDATE',
      entity: 'closeout_pack',
      entity_id: failedRecord.id,
      diff: {
        before: serializeCloseoutPack(initialRecord),
        after: serializeCloseoutPack(failedRecord),
      },
      ip_address: context.ip_address,
      user_agent: context.user_agent,
    }).catch(() => {});

    recordBackgroundJob('closeout_pack.failed', {
      'hms.closeout_pack.id': publicId,
    });

    throw error;
  }
};

const downloadCloseoutPack = async (id, context = {}) => {
  assertEvidencePermission(context);
  const resolvedId = await resolveCloseoutPackId(id);
  const record = ensureScopedRecord(await closeoutPackRepository.findById(resolvedId), context);
  if (record.status !== 'READY' || !record.output_storage_path) {
    throw new HttpError('errors.closeout_pack.not_found', 404);
  }

  const storage = createStorageService();
  const buffer = await storage.download(record.output_storage_path);

  await createAuditLog({
    tenant_id: record.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'EXPORT',
    entity: 'closeout_pack',
    entity_id: record.id,
    diff: { after: serializeCloseoutPack(record) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return {
    buffer,
    file_name: record.output_file_name || `${record.human_friendly_id || record.id}.bin`,
    mime_type: record.output_mime_type || 'application/octet-stream',
  };
};

module.exports = {
  createCloseoutPack,
  downloadCloseoutPack,
  getCloseoutPackById,
  listCloseoutPacks,
};
