/**
 * Pharmacy audit & compliance reporting.
 * Projects real audit_log rows — never invents diff fields.
 */

const prisma = require('@prisma/client');

/** Single allow-list for pharmacy-relevant audit entities (staff + compliance). */
const PHARMACY_AUDIT_ENTITIES = Object.freeze([
  'pharmacy_order',
  'pharmacy_dispense_attestation',
  'dispense_log',
  'drug',
  'inventory_stock',
  'stock_adjustment',
  'stock_movement',
  'payment',
  'purchase_order',
  'goods_receipt',
  'refund',
  'billing_adjustment',
]);

const PHARMACY_STOCK_AUDIT_ENTITIES = Object.freeze([
  'stock_adjustment',
  'stock_movement',
]);

const PHARMACY_RX_CONTROLLED_AUDIT_ENTITIES = Object.freeze([
  'pharmacy_order',
  'pharmacy_dispense_attestation',
  'dispense_log',
]);

const PERMISSION_ASSIGNMENT_AUDIT_ENTITIES = Object.freeze([
  'role_permission',
  'user_role',
  'user_permission',
  'api_key_permission',
]);

const PRICE_DIFF_FIELDS = Object.freeze([
  'buy_unit_price',
  'unit_price',
  'transfer_unit_price',
  'amount',
  'price',
]);

const QUANTITY_DIFF_FIELDS = Object.freeze([
  'quantity',
  'qty',
  'quantity_dispensed',
  'quantity_change',
  'adjustment_qty',
  'quantity_delta',
]);

const asNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const normalizeString = (value) => {
  if (value == null) return '';
  return String(value).trim();
};

const buildAuditScopeWhere = (scope = {}, extra = {}) => {
  const where = {
    deleted_at: null,
    ...extra,
  };
  if (scope.tenant_id) where.tenant_id = scope.tenant_id;
  return where;
};

const resolveStaffLabel = (user) => {
  if (!user) return null;
  const hfi = normalizeString(user.human_friendly_id);
  const name = [
    normalizeString(user.profile?.first_name),
    normalizeString(user.profile?.last_name),
  ]
    .filter(Boolean)
    .join(' ');
  if (hfi && name) return `${hfi} · ${name}`;
  if (hfi || name) return hfi || name;
  return normalizeString(user.email) || null;
};

const loadUserLabelMap = async (userIds = []) => {
  const ids = Array.from(new Set(userIds.map((id) => normalizeString(id)).filter(Boolean)));
  if (ids.length === 0) return new Map();
  const users = await prisma.user.findMany({
    where: { id: { in: ids }, deleted_at: null },
    select: {
      id: true,
      human_friendly_id: true,
      email: true,
      profile: {
        select: {
          first_name: true,
          last_name: true,
        },
      },
    },
  });
  return new Map(users.map((user) => [user.id, resolveStaffLabel(user) || user.id]));
};

const serializeDiff = (diffJson) => {
  if (diffJson == null) return null;
  if (typeof diffJson === 'string') return diffJson;
  try {
    return JSON.stringify(diffJson);
  } catch {
    return null;
  }
};

const isPlainObject = (value) =>
  value != null && typeof value === 'object' && !Array.isArray(value);

const extractFromTo = (entry) => {
  if (!isPlainObject(entry)) {
    return { previous: null, next: entry ?? null };
  }
  const previous = entry.from ?? entry.old ?? entry.before ?? entry.previous ?? null;
  const next = entry.to ?? entry.new ?? entry.after ?? entry.next ?? null;
  if (previous != null || next != null) {
    return { previous, next };
  }
  return { previous: null, next: entry };
};

/**
 * Expand diff_json into field-level rows using only keys present on the payload.
 */
const expandDiffFields = (diffJson) => {
  if (!isPlainObject(diffJson)) return [];

  const rows = [];
  const before = isPlainObject(diffJson.before) ? diffJson.before : null;
  const after = isPlainObject(diffJson.after) ? diffJson.after : null;

  if (before || after) {
    const keys = new Set([
      ...Object.keys(before || {}),
      ...Object.keys(after || {}),
    ]);
    for (const field of keys) {
      rows.push({
        field,
        previous_value: before ? before[field] ?? null : null,
        new_value: after ? after[field] ?? null : null,
      });
    }
  }

  for (const [field, entry] of Object.entries(diffJson)) {
    if (field === 'before' || field === 'after' || field === 'original_action') {
      continue;
    }
    if (rows.some((row) => row.field === field)) continue;
    const { previous, next } = extractFromTo(entry);
    rows.push({
      field,
      previous_value: previous,
      new_value: next,
    });
  }

  return rows;
};

const classifyDiffField = (field) => {
  const normalized = normalizeString(field).toLowerCase();
  if (PRICE_DIFF_FIELDS.includes(normalized) || normalized.includes('price') || normalized.includes('amount')) {
    return 'currency';
  }
  if (
    QUANTITY_DIFF_FIELDS.includes(normalized) ||
    normalized.includes('quantity') ||
    normalized.endsWith('_qty') ||
    normalized === 'qty'
  ) {
    return 'quantity';
  }
  return 'plain';
};

const formatScalar = (value) => {
  if (value == null) return null;
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
};

const projectDiffValueRow = ({ field, previous_value, new_value, currency = null }) => {
  const kind = classifyDiffField(field);
  const base = {
    field,
    previous_amount: null,
    new_amount: null,
    previous_quantity: null,
    new_quantity: null,
    previous_value: null,
    new_value: null,
    currency: kind === 'currency' ? currency : null,
    value_kind: kind,
  };
  if (kind === 'currency') {
    base.previous_amount = previous_value == null ? null : asNumber(previous_value);
    base.new_amount = new_value == null ? null : asNumber(new_value);
    return base;
  }
  if (kind === 'quantity') {
    base.previous_quantity = previous_value == null ? null : asNumber(previous_value);
    base.new_quantity = new_value == null ? null : asNumber(new_value);
    return base;
  }
  base.previous_value = formatScalar(previous_value);
  base.new_value = formatScalar(new_value);
  return base;
};

const isDeniedAccessDiff = (diffJson) => {
  if (!isPlainObject(diffJson)) return false;
  const decision =
    diffJson.decision ||
    diffJson.after?.decision ||
    diffJson.details?.decision ||
    null;
  const reason =
    diffJson.reason ||
    diffJson.after?.reason ||
    diffJson.details?.reason ||
    null;
  const normalizedDecision = normalizeString(decision).toUpperCase();
  if (normalizedDecision === 'DENY' || normalizedDecision === 'DENIED') return true;
  const normalizedReason = normalizeString(reason).toLowerCase();
  return (
    normalizedReason.includes('denied') ||
    normalizedReason.includes('insufficient') ||
    normalizedReason.includes('unauthorized')
  );
};

const deniedReasonFromDiff = (diffJson) => {
  if (!isPlainObject(diffJson)) return null;
  return (
    formatScalar(
      diffJson.reason ||
        diffJson.after?.reason ||
        diffJson.details?.reason ||
        diffJson.after?.decision ||
        diffJson.decision ||
        null
    ) || null
  );
};

const hasPriceKeysInDiff = (diffJson) => {
  if (!isPlainObject(diffJson)) return false;
  return expandDiffFields(diffJson).some((row) => classifyDiffField(row.field) === 'currency');
};

const loadPharmacyAuditLogs = async (
  scope,
  range,
  {
    actions = null,
    entities = Array.from(PHARMACY_AUDIT_ENTITIES),
    extraWhere = {},
  } = {}
) => {
  const where = buildAuditScopeWhere(scope, {
    created_at: { gte: range.from, lte: range.to },
    entity: { in: entities },
    ...extraWhere,
  });
  if (actions && actions.length > 0) {
    where.action = { in: actions };
  }

  return prisma.audit_log.findMany({
    where,
    select: {
      id: true,
      created_at: true,
      action: true,
      entity: true,
      entity_id: true,
      user_id: true,
      diff_json: true,
      ip_address: true,
    },
    orderBy: { created_at: 'desc' },
    take: 5000,
  });
};

const emptyAnalytics = (title, columns, summary = {}) => ({
  invalid: true,
  title,
  subtitle: 'Invalid date range',
  columns,
  rows: [],
  summary,
});

const withLabels = async (logs) => {
  const labels = await loadUserLabelMap(logs.map((log) => log.user_id).filter(Boolean));
  return { logs, labels };
};

const mapActorRow = (log, labels) => ({
  audit_log_id: log.id,
  user: log.user_id ? labels.get(log.user_id) || log.user_id : null,
  entity: log.entity,
  entity_id: log.entity_id,
  created_at: log.created_at ? new Date(log.created_at).toISOString() : null,
  action: log.action,
});

const buildWhoCreatedAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = ['user', 'entity', 'entity_id', 'created_at'];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Who created a transaction', columns, { event_count: 0 });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, { actions: ['CREATE'] })
  );
  const rows = logs.map((log) => {
    const mapped = mapActorRow(log, labels);
    return {
      user: mapped.user,
      entity: mapped.entity,
      entity_id: mapped.entity_id,
      created_at: mapped.created_at,
      audit_log_id: mapped.audit_log_id,
    };
  });

  return {
    invalid: false,
    title: 'Who created a transaction',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · action=CREATE`,
    columns,
    rows,
    summary: { event_count: rows.length },
  };
};

const buildWhoEditedAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = ['user', 'entity', 'entity_id', 'created_at'];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Who edited it', columns, { event_count: 0 });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, { actions: ['UPDATE'] })
  );
  const rows = logs.map((log) => {
    const mapped = mapActorRow(log, labels);
    return {
      user: mapped.user,
      entity: mapped.entity,
      entity_id: mapped.entity_id,
      created_at: mapped.created_at,
      audit_log_id: mapped.audit_log_id,
    };
  });

  return {
    invalid: false,
    title: 'Who edited it',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · action=UPDATE`,
    columns,
    rows,
    summary: { event_count: rows.length },
  };
};

const buildWhoDeletedAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = ['user', 'entity', 'entity_id', 'created_at', 'action'];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Who deleted/voided it', columns, { event_count: 0 });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, { actions: ['DELETE', 'UPDATE'] })
  );

  const rows = logs
    .filter((log) => {
      if (log.action === 'DELETE') return true;
      const original = normalizeString(log.diff_json?.original_action).toUpperCase();
      return original === 'CANCEL' || original === 'VOID' || original.startsWith('CANCEL_') || original.startsWith('VOID_');
    })
    .map((log) => {
      const mapped = mapActorRow(log, labels);
      return {
        user: mapped.user,
        entity: mapped.entity,
        entity_id: mapped.entity_id,
        created_at: mapped.created_at,
        action: log.action,
        audit_log_id: mapped.audit_log_id,
      };
    });

  return {
    invalid: false,
    title: 'Who deleted/voided it',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · DELETE / CANCELLED`,
    columns,
    rows,
    summary: { event_count: rows.length },
  };
};

const buildPreviousVsNewAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = [
    'changed_at',
    'user',
    'entity',
    'entity_id',
    'field',
    'previous_amount',
    'new_amount',
    'previous_quantity',
    'new_quantity',
    'previous_value',
    'new_value',
    'currency',
  ];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Previous vs new values', columns, { change_count: 0 });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, { actions: ['UPDATE', 'CREATE', 'DELETE'] })
  );

  const drugIds = logs.filter((log) => log.entity === 'drug').map((log) => log.entity_id).filter(Boolean);
  const drugs =
    drugIds.length > 0
      ? await prisma.drug.findMany({
          where: {
            deleted_at: null,
            ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
            id: { in: Array.from(new Set(drugIds)) },
          },
          select: { id: true, currency: true },
        })
      : [];
  const currencyByDrug = new Map(drugs.map((drug) => [drug.id, normalizeString(drug.currency) || null]));

  const rows = [];
  for (const log of logs) {
    const fields = expandDiffFields(log.diff_json);
    if (fields.length === 0) continue;
    const mapped = mapActorRow(log, labels);
    const currency = log.entity === 'drug' ? currencyByDrug.get(log.entity_id) || null : null;
    for (const fieldRow of fields) {
      const projected = projectDiffValueRow({
        field: fieldRow.field,
        previous_value: fieldRow.previous_value,
        new_value: fieldRow.new_value,
        currency,
      });
      rows.push({
        changed_at: mapped.created_at,
        user: mapped.user,
        entity: mapped.entity,
        entity_id: mapped.entity_id,
        audit_log_id: mapped.audit_log_id,
        ...projected,
      });
    }
  }

  return {
    invalid: false,
    title: 'Previous vs new values',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · diff_json fields`,
    columns,
    rows,
    summary: { change_count: rows.length },
  };
};

const buildChangeDateTimeAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = ['created_at', 'user', 'action', 'entity', 'entity_id'];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Date/time of changes', columns, { event_count: 0 });
  }

  const { logs, labels } = await withLabels(await loadPharmacyAuditLogs(scope, range));
  const rows = logs
    .map((log) => {
      const mapped = mapActorRow(log, labels);
      return {
        created_at: mapped.created_at,
        user: mapped.user,
        action: mapped.action,
        entity: mapped.entity,
        entity_id: mapped.entity_id,
        audit_log_id: mapped.audit_log_id,
      };
    })
    .sort((a, b) => String(b.created_at || '').localeCompare(String(a.created_at || '')));

  return {
    invalid: false,
    title: 'Date/time of changes',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · sorted by created_at`,
    columns,
    rows,
    summary: { event_count: rows.length },
  };
};

const buildAuditStockAdjustmentsAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = ['created_at', 'user', 'action', 'entity', 'entity_id', 'diff'];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Stock adjustments', columns, { event_count: 0 });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, {
      entities: Array.from(PHARMACY_STOCK_AUDIT_ENTITIES),
    })
  );
  const rows = logs.map((log) => {
    const mapped = mapActorRow(log, labels);
    return {
      created_at: mapped.created_at,
      user: mapped.user,
      action: mapped.action,
      entity: mapped.entity,
      entity_id: mapped.entity_id,
      diff: serializeDiff(log.diff_json),
      audit_log_id: mapped.audit_log_id,
    };
  });

  return {
    invalid: false,
    title: 'Stock adjustments',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · stock_adjustment/stock_movement`,
    columns,
    rows,
    summary: { event_count: rows.length },
  };
};

const buildAuditPriceChangesAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = [
    'changed_at',
    'user',
    'entity_id',
    'field',
    'previous_amount',
    'new_amount',
    'currency',
  ];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Price changes', columns, { change_count: 0 });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, {
      actions: ['UPDATE'],
      entities: ['drug'],
    })
  );

  const drugIds = logs.map((log) => log.entity_id).filter(Boolean);
  const drugs =
    drugIds.length > 0
      ? await prisma.drug.findMany({
          where: {
            deleted_at: null,
            ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
            id: { in: Array.from(new Set(drugIds)) },
          },
          select: { id: true, name: true, currency: true },
        })
      : [];
  const drugById = new Map(drugs.map((drug) => [drug.id, drug]));

  const rows = [];
  for (const log of logs) {
    if (!hasPriceKeysInDiff(log.diff_json)) continue;
    const mapped = mapActorRow(log, labels);
    const drug = drugById.get(log.entity_id);
    const currency = normalizeString(drug?.currency) || null;
    for (const fieldRow of expandDiffFields(log.diff_json)) {
      if (classifyDiffField(fieldRow.field) !== 'currency') continue;
      const projected = projectDiffValueRow({
        field: fieldRow.field,
        previous_value: fieldRow.previous_value,
        new_value: fieldRow.new_value,
        currency,
      });
      rows.push({
        changed_at: mapped.created_at,
        user: mapped.user,
        entity_id: mapped.entity_id,
        drug: drug?.name || mapped.entity_id,
        field: projected.field,
        previous_amount: projected.previous_amount,
        new_amount: projected.new_amount,
        currency: projected.currency,
        audit_log_id: mapped.audit_log_id,
      });
    }
  }

  return {
    invalid: false,
    title: 'Price changes',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · drug price keys in diff`,
    columns,
    rows,
    summary: { change_count: rows.length },
  };
};

const buildUserPermissionsAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = [
    'created_at',
    'user',
    'action',
    'entity',
    'entity_id',
    'field',
    'previous_value',
    'new_value',
  ];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('User permissions', columns, { event_count: 0, available: false });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, {
      entities: Array.from(PERMISSION_ASSIGNMENT_AUDIT_ENTITIES),
    })
  );

  if (logs.length === 0) {
    return {
      invalid: false,
      title: 'User permissions',
      subtitle: 'No permission-assignment audits in range',
      columns,
      rows: [],
      summary: { event_count: 0, available: false },
    };
  }

  const rows = [];
  for (const log of logs) {
    const mapped = mapActorRow(log, labels);
    const fields = expandDiffFields(log.diff_json);
    if (fields.length === 0) {
      rows.push({
        created_at: mapped.created_at,
        user: mapped.user,
        action: mapped.action,
        entity: mapped.entity,
        entity_id: mapped.entity_id,
        field: null,
        previous_value: null,
        new_value: null,
        audit_log_id: mapped.audit_log_id,
      });
      continue;
    }
    for (const fieldRow of fields) {
      rows.push({
        created_at: mapped.created_at,
        user: mapped.user,
        action: mapped.action,
        entity: mapped.entity,
        entity_id: mapped.entity_id,
        field: fieldRow.field,
        previous_value: formatScalar(fieldRow.previous_value),
        new_value: formatScalar(fieldRow.new_value),
        audit_log_id: mapped.audit_log_id,
      });
    }
  }

  return {
    invalid: false,
    title: 'User permissions',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · permission-assignment audits`,
    columns,
    rows,
    summary: { event_count: rows.length, available: true },
  };
};

const buildUnauthorizedAttemptsAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const columns = ['created_at', 'user', 'action', 'entity', 'entity_id', 'reason'];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Unauthorized attempts', columns, { event_count: 0 });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, {
      actions: ['ACCESS', 'EXPORT'],
      entities: Array.from(PHARMACY_AUDIT_ENTITIES),
    })
  );

  const rows = logs
    .filter((log) => isDeniedAccessDiff(log.diff_json))
    .map((log) => {
      const mapped = mapActorRow(log, labels);
      return {
        created_at: mapped.created_at,
        user: mapped.user,
        action: mapped.action,
        entity: mapped.entity,
        entity_id: mapped.entity_id,
        reason: deniedReasonFromDiff(log.diff_json),
        audit_log_id: mapped.audit_log_id,
      };
    });

  return {
    invalid: false,
    title: 'Unauthorized attempts',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · denied ACCESS/EXPORT`,
    columns,
    rows,
    summary: { event_count: rows.length },
  };
};

const buildPrescriptionControlledAuditAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const columns = ['created_at', 'user', 'action', 'entity', 'entity_id', 'diff'];
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return emptyAnalytics('Prescription/controlled-drug audit trail', columns, {
      event_count: 0,
    });
  }

  const { logs, labels } = await withLabels(
    await loadPharmacyAuditLogs(scope, range, {
      entities: Array.from(PHARMACY_RX_CONTROLLED_AUDIT_ENTITIES),
    })
  );
  const rows = logs.map((log) => {
    const mapped = mapActorRow(log, labels);
    return {
      created_at: mapped.created_at,
      user: mapped.user,
      action: mapped.action,
      entity: mapped.entity,
      entity_id: mapped.entity_id,
      diff: serializeDiff(log.diff_json),
      audit_log_id: mapped.audit_log_id,
    };
  });

  return {
    invalid: false,
    title: 'Prescription/controlled-drug audit trail',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)} · Rx/controlled entities`,
    columns,
    rows,
    summary: { event_count: rows.length },
  };
};

const wrapRunner = (builder, resolveDateRange) => async (scope, parameters = {}) => {
  const analytics = await builder(scope, parameters, resolveDateRange);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const createPharmacyAuditDatasetRunners = (resolveDateRange) =>
  Object.freeze({
    pharmacy_audit_who_created: wrapRunner(buildWhoCreatedAnalytics, resolveDateRange),
    pharmacy_audit_who_edited: wrapRunner(buildWhoEditedAnalytics, resolveDateRange),
    pharmacy_audit_who_deleted: wrapRunner(buildWhoDeletedAnalytics, resolveDateRange),
    pharmacy_audit_previous_vs_new: wrapRunner(buildPreviousVsNewAnalytics, resolveDateRange),
    pharmacy_audit_change_datetime: wrapRunner(buildChangeDateTimeAnalytics, resolveDateRange),
    pharmacy_audit_stock_adjustments: wrapRunner(
      buildAuditStockAdjustmentsAnalytics,
      resolveDateRange
    ),
    pharmacy_audit_price_changes: wrapRunner(buildAuditPriceChangesAnalytics, resolveDateRange),
    pharmacy_audit_user_permissions: wrapRunner(buildUserPermissionsAnalytics, resolveDateRange),
    pharmacy_audit_unauthorized: wrapRunner(buildUnauthorizedAttemptsAnalytics, resolveDateRange),
    pharmacy_audit_rx_controlled: wrapRunner(
      buildPrescriptionControlledAuditAnalytics,
      resolveDateRange
    ),
  });

module.exports = {
  PHARMACY_AUDIT_ENTITIES,
  PHARMACY_STOCK_AUDIT_ENTITIES,
  PHARMACY_RX_CONTROLLED_AUDIT_ENTITIES,
  PERMISSION_ASSIGNMENT_AUDIT_ENTITIES,
  PRICE_DIFF_FIELDS,
  QUANTITY_DIFF_FIELDS,
  expandDiffFields,
  projectDiffValueRow,
  classifyDiffField,
  isDeniedAccessDiff,
  createPharmacyAuditDatasetRunners,
  buildWhoCreatedAnalytics,
  buildWhoEditedAnalytics,
  buildWhoDeletedAnalytics,
  buildPreviousVsNewAnalytics,
  buildChangeDateTimeAnalytics,
  buildAuditStockAdjustmentsAnalytics,
  buildAuditPriceChangesAnalytics,
  buildUserPermissionsAnalytics,
  buildUnauthorizedAttemptsAnalytics,
  buildPrescriptionControlledAuditAnalytics,
};
