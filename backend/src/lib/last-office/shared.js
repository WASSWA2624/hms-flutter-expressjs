const crypto = require('crypto');
const { HttpError } = require('@lib/errors');
const { resolvePublicIdentifier, resolveIdentifierForFilter, resolveIdentifierForPayload } = require('@lib/billing/identifiers');

const normalizeString = (value) => String(value || '').trim();
const resolveDisplayIdentifier = (...values) => resolvePublicIdentifier(...values) || values.find(Boolean) || null;

const createPublicId = (prefix = 'OFF') => {
  const now = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `${prefix}-${now}${random}`.slice(0, 32);
};

const buildRecordEtag = (...parts) => crypto
  .createHash('sha256')
  .update(parts.filter(Boolean).join(':'))
  .digest('hex');

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: page * limit < total,
  hasPreviousPage: page > 1,
});

const decimalToString = (value) => {
  if (value === undefined || value === null) return null;
  return String(value);
};

const serializeBase = (record) => ({
  id: resolveDisplayIdentifier(record?.human_friendly_id, record?.id),
  human_friendly_id: resolveDisplayIdentifier(record?.human_friendly_id, record?.id),
  tenant_id: resolveDisplayIdentifier(record?.tenant?.human_friendly_id, record?.tenant_id),
  facility_id: resolveDisplayIdentifier(record?.facility?.human_friendly_id, record?.facility_id),
  branch_id: resolveDisplayIdentifier(record?.branch?.human_friendly_id, record?.branch_id),
  version: Number(record?.version || 1),
  etag: record?.etag || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeOfficeContext = (record) => ({
  ...serializeBase(record),
  shift_id: resolvePublicIdentifier(record?.shift?.human_friendly_id, record?.shift_id),
  opened_by_user_id: resolvePublicIdentifier(record?.opened_by?.human_friendly_id, record?.opened_by_user_id),
  current_holder_user_id: resolvePublicIdentifier(
    record?.current_holder?.human_friendly_id,
    record?.current_holder_user_id
  ),
  office_date: record?.office_date || null,
  status: record?.status || null,
  opened_at: record?.opened_at || null,
  closed_at: record?.closed_at || null,
  handover_due_at: record?.handover_due_at || null,
  notes: record?.notes || null,
  metadata_json: record?.metadata_json || null,
});

const serializeShiftClose = (record) => ({
  ...serializeBase(record),
  office_context_id: resolvePublicIdentifier(record?.office_context?.human_friendly_id, record?.office_context_id),
  shift_id: resolvePublicIdentifier(record?.shift?.human_friendly_id, record?.shift_id),
  closed_by_user_id: resolvePublicIdentifier(record?.closed_by?.human_friendly_id, record?.closed_by_user_id),
  approved_by_user_id: resolvePublicIdentifier(record?.approved_by?.human_friendly_id, record?.approved_by_user_id),
  status: record?.status || null,
  totals_json: record?.totals_json || null,
  reconciliation_json: record?.reconciliation_json || null,
  expected_amount: decimalToString(record?.expected_amount),
  actual_amount: decimalToString(record?.actual_amount),
  variance_amount: decimalToString(record?.variance_amount),
  submitted_at: record?.submitted_at || null,
  approved_at: record?.approved_at || null,
  notes: record?.notes || null,
  evidence_json: record?.evidence_json || null,
});

const serializeDayClose = (record) => ({
  ...serializeBase(record),
  office_context_id: resolvePublicIdentifier(record?.office_context?.human_friendly_id, record?.office_context_id),
  submitted_by_user_id: resolvePublicIdentifier(record?.submitted_by?.human_friendly_id, record?.submitted_by_user_id),
  approved_by_user_id: resolvePublicIdentifier(record?.approved_by?.human_friendly_id, record?.approved_by_user_id),
  status: record?.status || null,
  checklist_json: record?.checklist_json || null,
  blockers_json: record?.blockers_json || null,
  unresolved_items_json: record?.unresolved_items_json || null,
  submitted_at: record?.submitted_at || null,
  approved_at: record?.approved_at || null,
  notes: record?.notes || null,
  evidence_json: record?.evidence_json || null,
});

const serializeHandover = (record) => ({
  ...serializeBase(record),
  office_context_id: resolvePublicIdentifier(record?.office_context?.human_friendly_id, record?.office_context_id),
  from_user_id: resolvePublicIdentifier(record?.from_user?.human_friendly_id, record?.from_user_id),
  to_user_id: resolvePublicIdentifier(record?.to_user?.human_friendly_id, record?.to_user_id),
  status: record?.status || null,
  items_json: record?.items_json || null,
  signoff_notes: record?.signoff_notes || null,
  accepted_notes: record?.accepted_notes || null,
  submitted_at: record?.submitted_at || null,
  accepted_at: record?.accepted_at || null,
});

const serializeCustodySnapshot = (record) => ({
  ...serializeBase(record),
  office_context_id: resolvePublicIdentifier(record?.office_context?.human_friendly_id, record?.office_context_id),
  captured_by_user_id: resolvePublicIdentifier(record?.captured_by?.human_friendly_id, record?.captured_by_user_id),
  status: record?.status || null,
  asset_snapshot_json: record?.asset_snapshot_json || null,
  cash_drawer_snapshot_json: record?.cash_drawer_snapshot_json || null,
  controlled_items_json: record?.controlled_items_json || null,
  captured_at: record?.captured_at || null,
  finalized_at: record?.finalized_at || null,
  notes: record?.notes || null,
});

const serializeCloseoutPack = (record) => ({
  ...serializeBase(record),
  office_context_id: resolvePublicIdentifier(record?.office_context?.human_friendly_id, record?.office_context_id),
  shift_close_id: resolvePublicIdentifier(record?.shift_close?.human_friendly_id, record?.shift_close_id),
  day_close_id: resolvePublicIdentifier(record?.day_close?.human_friendly_id, record?.day_close_id),
  handover_id: resolvePublicIdentifier(record?.handover?.human_friendly_id, record?.handover_id),
  custody_snapshot_id: resolvePublicIdentifier(
    record?.custody_snapshot?.human_friendly_id,
    record?.custody_snapshot_id
  ),
  generated_by_user_id: resolvePublicIdentifier(
    record?.generated_by?.human_friendly_id,
    record?.generated_by_user_id
  ),
  status: record?.status || null,
  format: record?.format || null,
  output_storage_path: record?.output_storage_path || null,
  output_file_name: record?.output_file_name || null,
  output_mime_type: record?.output_mime_type || null,
  output_size_bytes: record?.output_size_bytes || null,
  checksum: record?.checksum || null,
  generated_at: record?.generated_at || null,
  error_message: record?.error_message || null,
  summary_json: record?.summary_json || null,
  parameter_overrides_json: record?.parameter_overrides_json || null,
});

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  tenant_id: req.user?.tenant_id || req.user?.tenantId || req.body?.tenant_id || null,
  facility_id: req.user?.facility_id || req.user?.facilityId || req.body?.facility_id || null,
  branch_id: req.user?.branch_id || req.user?.branchId || req.body?.branch_id || null,
  ip_address: req.ip,
  user_agent: req.get ? req.get('user-agent') : null,
});

const ensureTenantId = (value) => {
  const normalized = normalizeString(value);
  if (!normalized) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }
  return normalized;
};

const resolveScopedIdentifiers = async ({ payload = {}, context = {} } = {}) => ({
  tenant_id: ensureTenantId(context.tenant_id || payload.tenant_id),
  facility_id: await resolveIdentifierForPayload({
    value: payload.facility_id ?? context.facility_id,
    field: 'facility_id',
    model: 'facility',
    nullable: true,
    where: { tenant_id: context.tenant_id || payload.tenant_id || undefined },
  }),
  branch_id: await resolveIdentifierForPayload({
    value: payload.branch_id ?? context.branch_id,
    field: 'branch_id',
    model: 'branch',
    nullable: true,
    where: { tenant_id: context.tenant_id || payload.tenant_id || undefined },
  }),
});

const resolveListScopedIdentifiers = async ({ filters = {}, context = {} } = {}) => ({
  tenant_id: ensureTenantId(context.tenant_id || filters.tenant_id),
  facility_id: await resolveIdentifierForFilter({
    value: filters.facility_id ?? context.facility_id,
    model: 'facility',
    where: { tenant_id: context.tenant_id || filters.tenant_id || undefined },
  }),
  branch_id: await resolveIdentifierForFilter({
    value: filters.branch_id ?? context.branch_id,
    model: 'branch',
    where: { tenant_id: context.tenant_id || filters.tenant_id || undefined },
  }),
});

module.exports = {
  buildContext,
  buildRecordEtag,
  buildPagination,
  createPublicId,
  decimalToString,
  normalizeString,
  resolveListScopedIdentifiers,
  resolveScopedIdentifiers,
  serializeCloseoutPack,
  serializeCustodySnapshot,
  serializeDayClose,
  serializeHandover,
  serializeOfficeContext,
  serializeShiftClose,
};
