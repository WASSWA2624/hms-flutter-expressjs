/**
 * Pharmacy staff & user activity reporting.
 * Actors come only from real user FKs (attestation / audit_log)—never invented cashiers.
 */

const prisma = require('@prisma/client');
const { PHARMACY_AUDIT_ENTITIES } = require('@lib/reports/pharmacy-audit-analytics');

const asNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const normalizeString = (value) => {
  if (value == null) return '';
  return String(value).trim();
};

const roundMoney = (value) => Math.round(asNumber(value) * 100) / 100;

/**
 * Partition attributed staff amounts against period sales.
 * Unattributed remainder is explicit — never invent an "Unknown" staff performer.
 */
const summarizeStaffSalesPartition = ({
  staffRows = [],
  periodAmount = 0,
  periodQuantity = 0,
} = {}) => {
  const attributed_amount = roundMoney(
    staffRows.reduce((sum, row) => sum + asNumber(row?.amount), 0)
  );
  const attributed_quantity = staffRows.reduce(
    (sum, row) => sum + asNumber(row?.quantity_dispensed),
    0
  );
  const period_amount = roundMoney(periodAmount);
  const period_quantity = asNumber(periodQuantity);
  const unattributed_amount = roundMoney(Math.max(0, period_amount - attributed_amount));
  const unattributed_quantity = Math.max(0, period_quantity - attributed_quantity);
  return {
    amount: attributed_amount,
    quantity_dispensed: attributed_quantity,
    attributed_amount,
    attributed_quantity,
    unattributed_amount,
    unattributed_quantity,
    period_amount,
    period_quantity,
    staff_count: staffRows.filter((row) => normalizeString(row?.staff)).length,
  };
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

/**
 * Prefer ATTEST phase over PREPARE for the same order + batch.
 */
const pickAttestationUserId = (attestations = [], batchRef) => {
  const batch = normalizeString(batchRef);
  const matches = (Array.isArray(attestations) ? attestations : []).filter(
    (entry) => normalizeString(entry?.dispense_batch_ref) === batch
  );
  if (matches.length === 0) return null;
  const attest = matches.find((entry) => normalizeString(entry.phase).toUpperCase() === 'ATTEST');
  const chosen = attest || matches[0];
  return normalizeString(chosen?.attested_by_user_id) || null;
};

const resolveDispenseUnitPrice = (log) => {
  const drugPrice = asNumber(log?.pharmacy_order_item?.drug?.unit_price);
  if (drugPrice > 0) return drugPrice;

  const snapshot = log?.pharmacy_order_item?.pharmacy_order?.billing_snapshot;
  const lineItems = Array.isArray(snapshot?.line_items) ? snapshot.line_items : [];
  if (!lineItems.length) return drugPrice;

  const drugId = normalizeString(
    log?.pharmacy_order_item?.drug_id || log?.pharmacy_order_item?.drug?.id
  );
  const drugName = normalizeString(log?.pharmacy_order_item?.drug?.name);
  const match = lineItems.find((line) => {
    const lineId = normalizeString(line?.id);
    if (
      drugId &&
      (lineId === drugId ||
        lineId === normalizeString(log?.pharmacy_order_item?.drug?.human_friendly_id))
    ) {
      return true;
    }
    if (drugName && normalizeString(line?.label) === drugName) return true;
    return false;
  });
  return asNumber(match?.unit_price);
};

const buildPharmacyPatientScope = (scope = {}) => {
  const where = { deleted_at: null };
  if (scope.tenant_id) where.tenant_id = scope.tenant_id;
  if (scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const buildDispenseLogScopeWhere = (scope = {}) => ({
  deleted_at: null,
  pharmacy_order_item: {
    deleted_at: null,
    pharmacy_order: {
      deleted_at: null,
      patient: buildPharmacyPatientScope(scope),
    },
  },
});

const buildPharmacyBillingScopeWhere = (scope = {}) => {
  const where = {
    deleted_at: null,
    billing_entity: 'PHARMACY',
  };
  if (scope.tenant_id) where.tenant_id = scope.tenant_id;
  if (scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const buildAuditScopeWhere = (scope = {}, extra = {}) => {
  const where = {
    deleted_at: null,
    ...extra,
  };
  if (scope.tenant_id) where.tenant_id = scope.tenant_id;
  return where;
};

const loadAttributedDispenses = async (scope, range) => {
  const logs = await prisma.dispense_log.findMany({
    where: {
      ...buildDispenseLogScopeWhere(scope),
      status: 'DISPENSED',
      dispensed_at: { gte: range.from, lte: range.to },
    },
    select: {
      id: true,
      dispensed_at: true,
      quantity_dispensed: true,
      dispense_batch_ref: true,
      pharmacy_order_item: {
        select: {
          drug_id: true,
          drug: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
              unit_price: true,
            },
          },
          pharmacy_order: {
            select: {
              id: true,
              billing_snapshot: true,
              dispense_attestations: {
                where: { deleted_at: null },
                select: {
                  dispense_batch_ref: true,
                  phase: true,
                  attested_by_user_id: true,
                },
              },
            },
          },
        },
      },
    },
  });

  return logs.map((log) => {
    const qty = asNumber(log.quantity_dispensed);
    const unitPrice = resolveDispenseUnitPrice(log);
    const amount = roundMoney(unitPrice * qty);
    const userId = pickAttestationUserId(
      log?.pharmacy_order_item?.pharmacy_order?.dispense_attestations,
      log.dispense_batch_ref
    );
    return {
      id: log.id,
      dispensed_at: log.dispensed_at,
      quantity_dispensed: qty,
      amount,
      user_id: userId,
      pharmacy_order_id: log?.pharmacy_order_item?.pharmacy_order?.id || null,
    };
  });
};

const buildPharmacySalesByStaffAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const columns = ['staff', 'amount', 'quantity_dispensed'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Sales by staff',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: summarizeStaffSalesPartition(),
    };
  }

  const attributed = await loadAttributedDispenses(scope, range);
  const periodAmount = roundMoney(attributed.reduce((sum, row) => sum + asNumber(row.amount), 0));
  const periodQuantity = attributed.reduce((sum, row) => sum + asNumber(row.quantity_dispensed), 0);

  const staffIndex = new Map();
  attributed.forEach((entry) => {
    if (!entry.user_id) return;
    if (!staffIndex.has(entry.user_id)) {
      staffIndex.set(entry.user_id, {
        user_id: entry.user_id,
        amount: 0,
        quantity_dispensed: 0,
      });
    }
    const target = staffIndex.get(entry.user_id);
    target.amount = roundMoney(target.amount + entry.amount);
    target.quantity_dispensed += entry.quantity_dispensed;
  });

  const labels = await loadUserLabelMap(Array.from(staffIndex.keys()));
  const rows = Array.from(staffIndex.values())
    .map((entry) => ({
      staff: labels.get(entry.user_id) || entry.user_id,
      amount: entry.amount,
      quantity_dispensed: entry.quantity_dispensed,
    }))
    .sort((left, right) => right.amount - left.amount);

  const summary = summarizeStaffSalesPartition({
    staffRows: rows,
    periodAmount,
    periodQuantity,
  });
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Sales by staff',
    subtitle: `${fromLabel} to ${toLabel} · attestation-linked dispenses (unattributed ${summary.unattributed_amount})`,
    columns,
    rows,
    summary,
  };
};

const buildPharmacyDispensingByStaffAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const columns = ['staff', 'orders_created', 'quantity_dispensed'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Dispensing by staff',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { orders_created: 0, quantity_dispensed: 0, staff_count: 0 },
    };
  }

  const attributed = await loadAttributedDispenses(scope, range);
  const staffIndex = new Map();
  attributed.forEach((entry) => {
    if (!entry.user_id) return;
    if (!staffIndex.has(entry.user_id)) {
      staffIndex.set(entry.user_id, {
        user_id: entry.user_id,
        orderIds: new Set(),
        quantity_dispensed: 0,
      });
    }
    const target = staffIndex.get(entry.user_id);
    if (entry.pharmacy_order_id) target.orderIds.add(entry.pharmacy_order_id);
    target.quantity_dispensed += entry.quantity_dispensed;
  });

  const labels = await loadUserLabelMap(Array.from(staffIndex.keys()));
  const rows = Array.from(staffIndex.values())
    .map((entry) => ({
      staff: labels.get(entry.user_id) || entry.user_id,
      orders_created: entry.orderIds.size,
      quantity_dispensed: entry.quantity_dispensed,
    }))
    .sort((left, right) => right.quantity_dispensed - left.quantity_dispensed);

  const summary = rows.reduce(
    (acc, row) => {
      acc.orders_created += asNumber(row.orders_created);
      acc.quantity_dispensed += asNumber(row.quantity_dispensed);
      return acc;
    },
    { orders_created: 0, quantity_dispensed: 0, staff_count: rows.length }
  );

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Dispensing by staff',
    subtitle: `${fromLabel} to ${toLabel} · attestation actor`,
    columns,
    rows,
    summary,
  };
};

const aggregateAuditCountsByStaff = async ({
  scope,
  range,
  entities,
  actions,
  title,
  subtitleHint,
}) => {
  const columns = ['staff', 'event_count'];
  if (range.invalid) {
    return {
      invalid: true,
      title,
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { event_count: 0, staff_count: 0, unattributed_count: 0 },
    };
  }

  const logs = await prisma.audit_log.findMany({
    where: buildAuditScopeWhere(scope, {
      created_at: { gte: range.from, lte: range.to },
      entity: { in: entities },
      ...(actions?.length ? { action: { in: actions } } : {}),
      user_id: { not: null },
    }),
    select: {
      user_id: true,
    },
  });

  const staffIndex = new Map();
  let unattributed_count = 0;
  logs.forEach((log) => {
    const userId = normalizeString(log.user_id);
    if (!userId) {
      unattributed_count += 1;
      return;
    }
    staffIndex.set(userId, asNumber(staffIndex.get(userId)) + 1);
  });

  const labels = await loadUserLabelMap(Array.from(staffIndex.keys()));
  const rows = Array.from(staffIndex.entries())
    .map(([userId, event_count]) => ({
      staff: labels.get(userId) || userId,
      event_count,
    }))
    .sort((left, right) => right.event_count - left.event_count);

  const event_count = rows.reduce((sum, row) => sum + asNumber(row.event_count), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title,
    subtitle: `${fromLabel} to ${toLabel} · ${subtitleHint}`,
    columns,
    rows,
    summary: {
      event_count,
      staff_count: rows.length,
      unattributed_count,
    },
  };
};

const buildPharmacyPurchasesByStaffAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  return aggregateAuditCountsByStaff({
    scope,
    range: resolveDateRange(parameters),
    entities: ['purchase_order', 'goods_receipt'],
    actions: ['CREATE'],
    title: 'Purchases entered by staff',
    subtitleHint: 'audit CREATE on PO / goods_receipt',
  });
};

const buildPharmacyStockAdjustmentsByStaffAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  return aggregateAuditCountsByStaff({
    scope,
    range: resolveDateRange(parameters),
    entities: ['stock_adjustment'],
    actions: ['CREATE', 'UPDATE'],
    title: 'Stock adjustments by staff',
    subtitleHint: 'audit on stock_adjustment (no adjusted_by_user_id column)',
  });
};

const buildPharmacyRefundsByStaffAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const columns = ['staff', 'amount', 'event_count'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Refunds by staff',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0, event_count: 0, staff_count: 0 },
    };
  }

  const logs = await prisma.audit_log.findMany({
    where: buildAuditScopeWhere(scope, {
      created_at: { gte: range.from, lte: range.to },
      entity: 'refund',
      action: { in: ['CREATE'] },
      user_id: { not: null },
    }),
    select: {
      user_id: true,
      entity_id: true,
    },
  });

  const refundIds = logs.map((log) => log.entity_id).filter(Boolean);
  const refunds =
    refundIds.length > 0
      ? await prisma.refund.findMany({
          where: {
            id: { in: refundIds },
            deleted_at: null,
            payment: buildPharmacyBillingScopeWhere(scope),
          },
          select: { id: true, amount: true },
        })
      : [];
  const amountByRefund = new Map(refunds.map((row) => [row.id, asNumber(row.amount)]));

  const staffIndex = new Map();
  logs.forEach((log) => {
    const amount = amountByRefund.get(log.entity_id);
    if (amount == null) return;
    const userId = normalizeString(log.user_id);
    if (!userId) return;
    if (!staffIndex.has(userId)) {
      staffIndex.set(userId, { amount: 0, event_count: 0 });
    }
    const target = staffIndex.get(userId);
    target.amount = roundMoney(target.amount + amount);
    target.event_count += 1;
  });

  const labels = await loadUserLabelMap(Array.from(staffIndex.keys()));
  const rows = Array.from(staffIndex.entries())
    .map(([userId, entry]) => ({
      staff: labels.get(userId) || userId,
      amount: entry.amount,
      event_count: entry.event_count,
    }))
    .sort((left, right) => right.amount - left.amount);

  const summary = rows.reduce(
    (acc, row) => {
      acc.amount = roundMoney(acc.amount + asNumber(row.amount));
      acc.event_count += asNumber(row.event_count);
      return acc;
    },
    { amount: 0, event_count: 0, staff_count: rows.length }
  );

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Refunds by staff',
    subtitle: `${fromLabel} to ${toLabel} · audit creator on pharmacy refunds`,
    columns,
    rows,
    summary,
  };
};

const buildPharmacyDiscountsAuthorizedAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const columns = ['staff', 'amount', 'event_count'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Discounts authorized',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0, event_count: 0, staff_count: 0 },
    };
  }

  const logs = await prisma.audit_log.findMany({
    where: buildAuditScopeWhere(scope, {
      created_at: { gte: range.from, lte: range.to },
      entity: 'billing_adjustment',
      action: { in: ['CREATE', 'UPDATE'] },
      user_id: { not: null },
    }),
    select: {
      user_id: true,
      entity_id: true,
    },
  });

  const adjustmentIds = logs.map((log) => log.entity_id).filter(Boolean);
  const adjustments =
    adjustmentIds.length > 0
      ? await prisma.billing_adjustment.findMany({
          where: {
            id: { in: adjustmentIds },
            deleted_at: null,
            amount: { lt: 0 },
            invoice: buildPharmacyBillingScopeWhere(scope),
          },
          select: { id: true, amount: true },
        })
      : [];
  const amountByAdj = new Map(
    adjustments.map((row) => [row.id, Math.abs(asNumber(row.amount))])
  );

  const staffIndex = new Map();
  logs.forEach((log) => {
    const amount = amountByAdj.get(log.entity_id);
    if (amount == null) return;
    const userId = normalizeString(log.user_id);
    if (!userId) return;
    if (!staffIndex.has(userId)) {
      staffIndex.set(userId, { amount: 0, event_count: 0 });
    }
    const target = staffIndex.get(userId);
    target.amount = roundMoney(target.amount + amount);
    target.event_count += 1;
  });

  const labels = await loadUserLabelMap(Array.from(staffIndex.keys()));
  const rows = Array.from(staffIndex.entries())
    .map(([userId, entry]) => ({
      staff: labels.get(userId) || userId,
      amount: entry.amount,
      event_count: entry.event_count,
    }))
    .sort((left, right) => right.amount - left.amount);

  const summary = rows.reduce(
    (acc, row) => {
      acc.amount = roundMoney(acc.amount + asNumber(row.amount));
      acc.event_count += asNumber(row.event_count);
      return acc;
    },
    { amount: 0, event_count: 0, staff_count: rows.length }
  );

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Discounts authorized',
    subtitle: `${fromLabel} to ${toLabel} · audit on pharmacy billing_adjustment`,
    columns,
    rows,
    summary,
  };
};

const buildPharmacyVoidedTransactionsAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const columns = ['staff', 'voided_count'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Voided transactions',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { voided_count: 0, cancelled_orders: 0, staff_count: 0 },
    };
  }

  const [cancelledOrders, auditVoids] = await Promise.all([
    prisma.pharmacy_order.count({
      where: {
        deleted_at: null,
        status: 'CANCELLED',
        ordered_at: { gte: range.from, lte: range.to },
        patient: buildPharmacyPatientScope(scope),
      },
    }),
    prisma.audit_log.findMany({
      where: buildAuditScopeWhere(scope, {
        created_at: { gte: range.from, lte: range.to },
        entity: 'pharmacy_order',
        action: { in: ['DELETE'] },
        user_id: { not: null },
      }),
      select: { user_id: true },
    }),
  ]);

  const staffIndex = new Map();
  auditVoids.forEach((log) => {
    const userId = normalizeString(log.user_id);
    if (!userId) return;
    staffIndex.set(userId, asNumber(staffIndex.get(userId)) + 1);
  });

  const labels = await loadUserLabelMap(Array.from(staffIndex.keys()));
  const rows = Array.from(staffIndex.entries())
    .map(([userId, voided_count]) => ({
      staff: labels.get(userId) || userId,
      voided_count,
    }))
    .sort((left, right) => right.voided_count - left.voided_count);

  const voided_count = rows.reduce((sum, row) => sum + asNumber(row.voided_count), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Voided transactions',
    subtitle: `${fromLabel} to ${toLabel} · CANCELLED orders=${cancelledOrders}; staff voids from audit DELETE`,
    columns,
    rows,
    summary: {
      voided_count,
      cancelled_orders: cancelledOrders,
      staff_count: rows.length,
    },
  };
};

const buildPharmacyLoginActivityAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const columns = ['timestamp', 'staff', 'action'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Login/activity history',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { event_count: 0 },
    };
  }

  const logs = await prisma.audit_log.findMany({
    where: buildAuditScopeWhere(scope, {
      created_at: { gte: range.from, lte: range.to },
      action: { in: ['LOGIN', 'LOGOUT'] },
    }),
    select: {
      created_at: true,
      action: true,
      user_id: true,
    },
    orderBy: { created_at: 'desc' },
    take: 5000,
  });

  const labels = await loadUserLabelMap(logs.map((log) => log.user_id).filter(Boolean));
  const rows = logs.map((log) => ({
    timestamp: log.created_at ? new Date(log.created_at).toISOString() : null,
    staff: log.user_id ? labels.get(log.user_id) || log.user_id : null,
    action: log.action,
  }));

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Login/activity history',
    subtitle: `${fromLabel} to ${toLabel} · audit LOGIN/LOGOUT`,
    columns,
    rows,
    summary: { event_count: rows.length },
  };
};

const buildPharmacyUserProductivityAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const columns = ['date', 'staff', 'quantity_dispensed', 'amount'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'User productivity',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0, quantity_dispensed: 0, staff_count: 0 },
    };
  }

  const attributed = (await loadAttributedDispenses(scope, range)).filter((row) => row.user_id);
  const labels = await loadUserLabelMap(attributed.map((row) => row.user_id));
  const index = new Map();

  attributed.forEach((entry) => {
    const date = entry.dispensed_at
      ? new Date(entry.dispensed_at).toISOString().slice(0, 10)
      : null;
    if (!date) return;
    const key = `${date}|${entry.user_id}`;
    if (!index.has(key)) {
      index.set(key, {
        date,
        user_id: entry.user_id,
        quantity_dispensed: 0,
        amount: 0,
      });
    }
    const target = index.get(key);
    target.quantity_dispensed += entry.quantity_dispensed;
    target.amount = roundMoney(target.amount + entry.amount);
  });

  const rows = Array.from(index.values())
    .map((entry) => ({
      date: entry.date,
      staff: labels.get(entry.user_id) || entry.user_id,
      quantity_dispensed: entry.quantity_dispensed,
      amount: entry.amount,
    }))
    .sort((left, right) => {
      const dateCmp = String(left.date).localeCompare(String(right.date));
      if (dateCmp !== 0) return dateCmp;
      return asNumber(right.quantity_dispensed) - asNumber(left.quantity_dispensed);
    });

  const staffIds = new Set(attributed.map((row) => row.user_id));
  const summary = {
    amount: roundMoney(rows.reduce((sum, row) => sum + asNumber(row.amount), 0)),
    quantity_dispensed: rows.reduce((sum, row) => sum + asNumber(row.quantity_dispensed), 0),
    staff_count: staffIds.size,
  };

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'User productivity',
    subtitle: `${fromLabel} to ${toLabel} · dispenses per staff per day`,
    columns,
    rows,
    summary,
  };
};

const buildPharmacyAuditTrailAnalytics = async (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const columns = ['timestamp', 'action', 'entity', 'entity_id', 'staff', 'diff'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy audit trail',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { event_count: 0 },
    };
  }

  const logs = await prisma.audit_log.findMany({
    where: buildAuditScopeWhere(scope, {
      created_at: { gte: range.from, lte: range.to },
      entity: { in: Array.from(PHARMACY_AUDIT_ENTITIES) },
    }),
    select: {
      created_at: true,
      action: true,
      entity: true,
      entity_id: true,
      user_id: true,
      diff_json: true,
    },
    orderBy: { created_at: 'desc' },
    take: 5000,
  });

  const labels = await loadUserLabelMap(logs.map((log) => log.user_id).filter(Boolean));
  const rows = logs.map((log) => ({
    timestamp: log.created_at ? new Date(log.created_at).toISOString() : null,
    action: log.action,
    entity: log.entity,
    entity_id: log.entity_id,
    staff: log.user_id ? labels.get(log.user_id) || log.user_id : null,
    diff:
      log.diff_json == null
        ? null
        : typeof log.diff_json === 'string'
          ? log.diff_json
          : JSON.stringify(log.diff_json),
  }));

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy audit trail',
    subtitle: `${fromLabel} to ${toLabel} · pharmacy-relevant audit_log`,
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

const createPharmacyStaffDatasetRunners = (resolveDateRange) =>
  Object.freeze({
    pharmacy_sales_by_staff: wrapRunner(buildPharmacySalesByStaffAnalytics, resolveDateRange),
    pharmacy_dispensing_by_staff: wrapRunner(
      buildPharmacyDispensingByStaffAnalytics,
      resolveDateRange
    ),
    pharmacy_purchases_by_staff: wrapRunner(
      buildPharmacyPurchasesByStaffAnalytics,
      resolveDateRange
    ),
    pharmacy_stock_adjustments_by_staff: wrapRunner(
      buildPharmacyStockAdjustmentsByStaffAnalytics,
      resolveDateRange
    ),
    pharmacy_refunds_by_staff: wrapRunner(buildPharmacyRefundsByStaffAnalytics, resolveDateRange),
    pharmacy_discounts_authorized: wrapRunner(
      buildPharmacyDiscountsAuthorizedAnalytics,
      resolveDateRange
    ),
    pharmacy_voided_transactions: wrapRunner(
      buildPharmacyVoidedTransactionsAnalytics,
      resolveDateRange
    ),
    pharmacy_login_activity: wrapRunner(buildPharmacyLoginActivityAnalytics, resolveDateRange),
    pharmacy_user_productivity: wrapRunner(
      buildPharmacyUserProductivityAnalytics,
      resolveDateRange
    ),
    pharmacy_audit_trail: wrapRunner(buildPharmacyAuditTrailAnalytics, resolveDateRange),
  });

module.exports = {
  PHARMACY_AUDIT_ENTITIES,
  createPharmacyStaffDatasetRunners,
  pickAttestationUserId,
  summarizeStaffSalesPartition,
  buildPharmacySalesByStaffAnalytics,
  buildPharmacyDispensingByStaffAnalytics,
  buildPharmacyPurchasesByStaffAnalytics,
  buildPharmacyStockAdjustmentsByStaffAnalytics,
  buildPharmacyRefundsByStaffAnalytics,
  buildPharmacyDiscountsAuthorizedAnalytics,
  buildPharmacyVoidedTransactionsAnalytics,
  buildPharmacyLoginActivityAnalytics,
  buildPharmacyUserProductivityAnalytics,
  buildPharmacyAuditTrailAnalytics,
};
