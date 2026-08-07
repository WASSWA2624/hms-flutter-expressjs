/**
 * Pharmacy stock transfer reporting.
 * TRANSFER movements with from/to facilities; pending/completed derived from
 * paired ship+receive legs sharing transfer_group_id (no invented status enum).
 */

const prisma = require('@prisma/client');

const asNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const normalizeString = (value) => {
  if (value == null) return '';
  return String(value).trim();
};

const facilityLabel = (facility, fallback = 'Unassigned') =>
  normalizeString(facility?.name) || fallback;

/**
 * Absolute unit difference when both ship and receive quantities are recorded.
 */
const transferDiscrepancyQuantity = (shippedQty, receivedQty) =>
  Math.abs(asNumber(shippedQty) - asNumber(receivedQty));

/**
 * Derive transfer status from paired receipts — never invent fake statuses.
 * PENDING = ship leg only; COMPLETED = ship + receive recorded.
 */
const deriveTransferStatus = ({ hasShip, hasReceive } = {}) => {
  if (hasShip && hasReceive) return 'COMPLETED';
  if (hasShip) return 'PENDING';
  return null;
};

const isTransferReceiveLeg = (movement = {}) => {
  const facilityId = normalizeString(movement.facility_id);
  const toId = normalizeString(movement.to_facility_id);
  return Boolean(facilityId && toId && facilityId === toId);
};

const buildTransferMovementWhere = (scope, parameters = {}, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  const where = {
    deleted_at: null,
    movement_type: 'TRANSFER',
    inventory_item: {
      deleted_at: null,
      tenant_id: scope.tenant_id,
    },
  };
  if (scope.facility_id) {
    where.OR = [
      { facility_id: scope.facility_id },
      { from_facility_id: scope.facility_id },
      { to_facility_id: scope.facility_id },
    ];
  }
  if (!range.invalid && range.from && range.to) {
    where.occurred_at = { gte: range.from, lte: range.to };
  }
  return { where, range };
};

const loadTransferMovements = async (scope, parameters, resolveDateRange) => {
  const { where, range } = buildTransferMovementWhere(scope, parameters, resolveDateRange);
  if (range.invalid) {
    return { invalid: true, range, rows: [] };
  }
  const movements = await prisma.stock_movement.findMany({
    where,
    select: {
      id: true,
      inventory_item_id: true,
      facility_id: true,
      from_facility_id: true,
      to_facility_id: true,
      transfer_group_id: true,
      movement_type: true,
      reason: true,
      quantity: true,
      occurred_at: true,
      facility: { select: { id: true, name: true } },
      from_facility: { select: { id: true, name: true } },
      to_facility: { select: { id: true, name: true } },
      inventory_item: { select: { id: true, name: true } },
    },
    orderBy: [{ occurred_at: 'asc' }, { created_at: 'asc' }],
  });
  return { invalid: false, range, rows: movements };
};

/**
 * Collapse paired TRANSFER legs into one logical transfer per transfer_group_id
 * (fallback: single movement id when group unset).
 */
const aggregateTransferGroups = (movements = []) => {
  const groups = new Map();
  for (const entry of movements) {
    const groupKey =
      normalizeString(entry.transfer_group_id) || `solo:${normalizeString(entry.id)}`;
    if (!groups.has(groupKey)) {
      groups.set(groupKey, {
        transfer_group_id: normalizeString(entry.transfer_group_id) || null,
        ship: null,
        receive: null,
        legs: [],
      });
    }
    const group = groups.get(groupKey);
    group.legs.push(entry);
    if (isTransferReceiveLeg(entry)) {
      if (!group.receive) group.receive = entry;
    } else if (!group.ship) {
      group.ship = entry;
    }
  }

  return Array.from(groups.values()).map((group) => {
    const ship = group.ship || group.legs[0] || null;
    const receive = group.receive || null;
    const hasShip = Boolean(ship);
    const hasReceive = Boolean(receive);
    const shipped_quantity = hasShip ? asNumber(ship.quantity) : 0;
    const received_quantity = hasReceive ? asNumber(receive.quantity) : null;
    const status = deriveTransferStatus({ hasShip, hasReceive });
    const discrepancy_quantity =
      hasReceive && hasShip
        ? transferDiscrepancyQuantity(shipped_quantity, received_quantity)
        : null;
    const occurred = ship?.occurred_at || receive?.occurred_at || null;
    return {
      transfer_group_id: group.transfer_group_id,
      transfer_date: occurred ? new Date(occurred).toISOString() : null,
      transfer_status: status,
      inventory_item: ship?.inventory_item?.name || receive?.inventory_item?.name || 'Unknown',
      inventory_item_id: ship?.inventory_item_id || receive?.inventory_item_id || null,
      sending_branch: facilityLabel(ship?.from_facility || ship?.facility),
      receiving_branch: facilityLabel(
        ship?.to_facility || receive?.to_facility || receive?.facility
      ),
      from_facility_id: ship?.from_facility_id || receive?.from_facility_id || null,
      to_facility_id: ship?.to_facility_id || receive?.to_facility_id || null,
      quantity: shipped_quantity,
      shipped_quantity,
      received_quantity,
      discrepancy_quantity,
      has_discrepancy: discrepancy_quantity != null && discrepancy_quantity > 0,
    };
  });
};

const rangeSubtitle = (range, invalid, suffix) => {
  if (invalid) return 'Invalid date range';
  const fromLabel = range?.from ? range.from.toISOString().slice(0, 10) : '';
  const toLabel = range?.to ? range.to.toISOString().slice(0, 10) : '';
  return `${fromLabel} to ${toLabel}${suffix ? ` (${suffix})` : ''}`;
};

const mapMovementRow = (entry) => ({
  occurred_at: entry.occurred_at ? new Date(entry.occurred_at).toISOString() : null,
  inventory_item: entry?.inventory_item?.name || 'Unknown',
  inventory_item_id: entry.inventory_item_id,
  quantity: asNumber(entry.quantity),
  sending_branch: facilityLabel(entry.from_facility || entry.facility),
  receiving_branch: facilityLabel(entry.to_facility),
  transfer_group_id: normalizeString(entry.transfer_group_id) || null,
  transfer_leg: isTransferReceiveLeg(entry) ? 'RECEIVE' : 'SHIP',
  facility: facilityLabel(entry.facility),
});

const wrapRunner = (builder, resolveDateRange) => async (scope, parameters = {}) =>
  builder(scope, parameters, resolveDateRange);

const buildTransferQuantityAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const rows = loaded.rows.map(mapMovementRow);
  return {
    title: 'Transfer quantity',
    subtitle: rangeSubtitle(loaded.range, loaded.invalid, 'TRANSFER stock_movement units'),
    columns: [
      'occurred_at',
      'inventory_item',
      'quantity',
      'sending_branch',
      'receiving_branch',
      'transfer_leg',
    ],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      movement_count: rows.length,
    },
  };
};

const buildSendingBranchAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const ships = loaded.rows.filter((row) => !isTransferReceiveLeg(row));
  const byFacility = new Map();
  for (const entry of ships) {
    const key =
      normalizeString(entry.from_facility_id) ||
      normalizeString(entry.facility_id) ||
      'unassigned';
    const label = facilityLabel(entry.from_facility || entry.facility);
    if (!byFacility.has(key)) {
      byFacility.set(key, { facility: label, quantity: 0, transfer_count: 0 });
    }
    const bucket = byFacility.get(key);
    bucket.quantity += asNumber(entry.quantity);
    bucket.transfer_count += 1;
  }
  const rows = Array.from(byFacility.values()).sort(
    (left, right) => asNumber(right.quantity) - asNumber(left.quantity)
  );
  return {
    title: 'Sending branch',
    subtitle: rangeSubtitle(loaded.range, loaded.invalid, 'TRANSFER ship legs by from_facility'),
    columns: ['facility', 'quantity', 'transfer_count'],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      transfer_count: rows.reduce((sum, row) => sum + asNumber(row.transfer_count), 0),
    },
  };
};

const buildReceivingBranchAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const byFacility = new Map();
  for (const entry of loaded.rows) {
    const toId = normalizeString(entry.to_facility_id);
    if (!toId) continue;
    const label = facilityLabel(entry.to_facility);
    if (!byFacility.has(toId)) {
      byFacility.set(toId, { facility: label, quantity: 0, transfer_count: 0 });
    }
    const bucket = byFacility.get(toId);
    // Count ship quantity toward destination once (prefer ship legs).
    if (isTransferReceiveLeg(entry)) continue;
    bucket.quantity += asNumber(entry.quantity);
    bucket.transfer_count += 1;
  }
  const rows = Array.from(byFacility.values()).sort(
    (left, right) => asNumber(right.quantity) - asNumber(left.quantity)
  );
  return {
    title: 'Receiving branch',
    subtitle: rangeSubtitle(loaded.range, loaded.invalid, 'TRANSFER destinations by to_facility'),
    columns: ['facility', 'quantity', 'transfer_count'],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      transfer_count: rows.reduce((sum, row) => sum + asNumber(row.transfer_count), 0),
    },
  };
};

const buildTransferDateAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const groups = aggregateTransferGroups(loaded.rows);
  const byDate = new Map();
  for (const group of groups) {
    const day = group.transfer_date ? group.transfer_date.slice(0, 10) : 'unknown';
    if (!byDate.has(day)) {
      byDate.set(day, { transfer_date: day, quantity: 0, transfer_count: 0 });
    }
    const bucket = byDate.get(day);
    bucket.quantity += asNumber(group.shipped_quantity);
    bucket.transfer_count += 1;
  }
  const rows = Array.from(byDate.values()).sort((left, right) =>
    String(left.transfer_date).localeCompare(String(right.transfer_date))
  );
  return {
    title: 'Transfer date',
    subtitle: rangeSubtitle(loaded.range, loaded.invalid, 'transfers by occurred_at day'),
    columns: ['transfer_date', 'quantity', 'transfer_count'],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      transfer_count: rows.reduce((sum, row) => sum + asNumber(row.transfer_count), 0),
    },
  };
};

const buildTransferStatusAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const groups = aggregateTransferGroups(loaded.rows).filter((row) => row.transfer_status);
  const rows = groups.map((group) => ({
    transfer_date: group.transfer_date,
    transfer_status: group.transfer_status,
    inventory_item: group.inventory_item,
    sending_branch: group.sending_branch,
    receiving_branch: group.receiving_branch,
    quantity: group.shipped_quantity,
  }));
  const pending_count = rows.filter((row) => row.transfer_status === 'PENDING').length;
  const completed_count = rows.filter((row) => row.transfer_status === 'COMPLETED').length;
  return {
    title: 'Transfer status',
    subtitle: rangeSubtitle(
      loaded.range,
      loaded.invalid,
      'derived PENDING|COMPLETED from paired receipts'
    ),
    columns: [
      'transfer_date',
      'transfer_status',
      'inventory_item',
      'sending_branch',
      'receiving_branch',
      'quantity',
    ],
    rows,
    summary: { transfer_count: rows.length, pending_count, completed_count },
  };
};

const buildProductsTransferredAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const groups = aggregateTransferGroups(loaded.rows);
  const rows = groups.map((group) => ({
    inventory_item: group.inventory_item,
    quantity: group.shipped_quantity,
    sending_branch: group.sending_branch,
    receiving_branch: group.receiving_branch,
    transfer_date: group.transfer_date,
    transfer_status: group.transfer_status,
  }));
  return {
    title: 'Products transferred',
    subtitle: rangeSubtitle(loaded.range, loaded.invalid, 'transfer groups'),
    columns: [
      'inventory_item',
      'quantity',
      'sending_branch',
      'receiving_branch',
      'transfer_date',
      'transfer_status',
    ],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      transfer_count: rows.length,
    },
  };
};

const buildPendingTransfersAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const rows = aggregateTransferGroups(loaded.rows)
    .filter((group) => group.transfer_status === 'PENDING')
    .map((group) => ({
      transfer_date: group.transfer_date,
      inventory_item: group.inventory_item,
      quantity: group.shipped_quantity,
      sending_branch: group.sending_branch,
      receiving_branch: group.receiving_branch,
      transfer_status: group.transfer_status,
    }));
  return {
    title: 'Pending transfers',
    subtitle: rangeSubtitle(loaded.range, loaded.invalid, 'ship without receive leg'),
    columns: [
      'transfer_date',
      'inventory_item',
      'quantity',
      'sending_branch',
      'receiving_branch',
      'transfer_status',
    ],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      transfer_count: rows.length,
    },
  };
};

const buildTransferDiscrepanciesAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const rows = aggregateTransferGroups(loaded.rows)
    .filter((group) => group.has_discrepancy)
    .map((group) => ({
      transfer_date: group.transfer_date,
      inventory_item: group.inventory_item,
      sending_branch: group.sending_branch,
      receiving_branch: group.receiving_branch,
      shipped_quantity: group.shipped_quantity,
      received_quantity: group.received_quantity,
      discrepancy_quantity: group.discrepancy_quantity,
    }));
  return {
    title: 'Transfer discrepancies',
    subtitle: rangeSubtitle(
      loaded.range,
      loaded.invalid,
      'abs(shipped − received) when both recorded'
    ),
    columns: [
      'transfer_date',
      'inventory_item',
      'sending_branch',
      'receiving_branch',
      'shipped_quantity',
      'received_quantity',
      'discrepancy_quantity',
    ],
    rows,
    summary: {
      discrepancy_quantity: rows.reduce(
        (sum, row) => sum + asNumber(row.discrepancy_quantity),
        0
      ),
      transfer_count: rows.length,
    },
  };
};

const buildTransfersBetweenBranchesAnalytics = async (scope, parameters, resolveDateRange) => {
  const loaded = await loadTransferMovements(scope, parameters, resolveDateRange);
  const groups = aggregateTransferGroups(loaded.rows);
  const byPair = new Map();
  for (const group of groups) {
    const key = `${group.sending_branch}→${group.receiving_branch}`;
    if (!byPair.has(key)) {
      byPair.set(key, {
        sending_branch: group.sending_branch,
        receiving_branch: group.receiving_branch,
        quantity: 0,
        transfer_count: 0,
      });
    }
    const bucket = byPair.get(key);
    bucket.quantity += asNumber(group.shipped_quantity);
    bucket.transfer_count += 1;
  }
  const rows = Array.from(byPair.values()).sort(
    (left, right) => asNumber(right.quantity) - asNumber(left.quantity)
  );
  return {
    title: 'Transfers between branches',
    subtitle: rangeSubtitle(loaded.range, loaded.invalid, 'from_facility → to_facility'),
    columns: ['sending_branch', 'receiving_branch', 'quantity', 'transfer_count'],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      transfer_count: rows.reduce((sum, row) => sum + asNumber(row.transfer_count), 0),
    },
  };
};

const createPharmacyTransferDatasetRunners = (resolveDateRange) =>
  Object.freeze({
    pharmacy_transfer_quantity: wrapRunner(buildTransferQuantityAnalytics, resolveDateRange),
    pharmacy_sending_branch: wrapRunner(buildSendingBranchAnalytics, resolveDateRange),
    pharmacy_receiving_branch: wrapRunner(buildReceivingBranchAnalytics, resolveDateRange),
    pharmacy_transfer_date: wrapRunner(buildTransferDateAnalytics, resolveDateRange),
    pharmacy_transfer_status: wrapRunner(buildTransferStatusAnalytics, resolveDateRange),
    pharmacy_products_transferred: wrapRunner(
      buildProductsTransferredAnalytics,
      resolveDateRange
    ),
    pharmacy_pending_transfers: wrapRunner(buildPendingTransfersAnalytics, resolveDateRange),
    pharmacy_transfer_discrepancies: wrapRunner(
      buildTransferDiscrepanciesAnalytics,
      resolveDateRange
    ),
    pharmacy_transfers_between_branches: wrapRunner(
      buildTransfersBetweenBranchesAnalytics,
      resolveDateRange
    ),
  });

module.exports = {
  createPharmacyTransferDatasetRunners,
  transferDiscrepancyQuantity,
  deriveTransferStatus,
  isTransferReceiveLeg,
  aggregateTransferGroups,
  buildTransferQuantityAnalytics,
  buildPendingTransfersAnalytics,
  buildTransferDiscrepanciesAnalytics,
};
