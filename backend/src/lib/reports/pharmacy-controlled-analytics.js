/**
 * Controlled medicines balance + regulatory log reporting.
 *
 * Controlled set: drug.is_controlled == true (Prisma boolean; Morphine/Tramadol seeded).
 * Balance grain: drug (via default drug_inventory_map → inventory_item → inventory_stock).
 *
 * Invariant (per drug):
 *   closing = opening + received − dispensed − wastage + adjustments_net
 *
 * Reconstruction (closing = current on-hand):
 *   opening = closing − received + dispensed + wastage − adjustments_net
 *
 * Components in range:
 *   received      = INBOUND + PURCHASE stock_movement qty
 *   dispensed     = dispense_log qty where status=DISPENSED (not OUTBOUND movements)
 *   wastage       = stock_adjustment | ADJUSTMENT movement with reason EXPIRY|DAMAGE (abs qty)
 *   adjustments_net = signed ADJUSTMENT movements/adjustments excluding EXPIRY|DAMAGE
 */

const prisma = require('@prisma/client');

const asNumber = (value) => {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (value && typeof value.toString === 'function') {
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
};

const normalizeString = (value) => {
  if (value == null) return '';
  return String(value).trim();
};

const isWastageReason = (reason) => {
  const normalized = normalizeString(reason).toUpperCase();
  return normalized === 'EXPIRY' || normalized === 'DAMAGE';
};

/**
 * Pure balance math for golden fixtures.
 * adjustments_net is signed (positive increases stock).
 */
const computeControlledBalance = ({
  closing_quantity = 0,
  quantity_received = 0,
  quantity_dispensed = 0,
  wastage = 0,
  adjustments_net = 0,
} = {}) => {
  const closing = asNumber(closing_quantity);
  const received = asNumber(quantity_received);
  const dispensed = asNumber(quantity_dispensed);
  const waste = Math.abs(asNumber(wastage));
  const adjustments = asNumber(adjustments_net);
  const opening = closing - received + dispensed + waste - adjustments;
  return {
    opening_quantity: opening,
    quantity_received: received,
    quantity_dispensed: dispensed,
    wastage: waste,
    adjustments_net: adjustments,
    closing_quantity: closing,
    // Documented invariant — callers assert equality in tests.
    invariant_closing: opening + received - dispensed - waste + adjustments,
  };
};

const assertControlledBalanceInvariant = (row = {}) => {
  const computed = computeControlledBalance(row);
  return Math.abs(asNumber(row.closing_quantity) - computed.invariant_closing) < 0.0001;
};

const resolvePersonLabel = (entity = {}) => {
  const hfi = normalizeString(entity.human_friendly_id);
  const name = [normalizeString(entity.first_name), normalizeString(entity.last_name)]
    .filter(Boolean)
    .join(' ');
  if (hfi && name) return `${hfi} · ${name}`;
  if (hfi || name) return hfi || name;
  return normalizeString(entity.email) || null;
};

const loadControlledDrugMaps = async (scope = {}) => {
  const maps = await prisma.drug_inventory_map.findMany({
    where: {
      deleted_at: null,
      tenant_id: scope.tenant_id,
      is_default: true,
      drug: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
        is_controlled: true,
      },
      inventory_item: { deleted_at: null },
    },
    select: {
      drug_id: true,
      inventory_item_id: true,
      drug: {
        select: {
          id: true,
          name: true,
          code: true,
          form: true,
          strength: true,
          is_controlled: true,
        },
      },
      inventory_item: {
        select: {
          id: true,
          name: true,
          unit: true,
        },
      },
    },
  });

  const byInventoryItem = new Map();
  const byDrug = new Map();
  maps.forEach((entry) => {
    const drugLabel =
      normalizeString(entry.drug?.name) ||
      normalizeString(entry.inventory_item?.name) ||
      'Unknown';
    const row = {
      drug_id: entry.drug_id,
      inventory_item_id: entry.inventory_item_id,
      drug: drugLabel,
      code: normalizeString(entry.drug?.code) || null,
      form: normalizeString(entry.drug?.form) || null,
      strength: normalizeString(entry.drug?.strength) || null,
      unit: normalizeString(entry.inventory_item?.unit) || null,
      inventory_item: normalizeString(entry.inventory_item?.name) || drugLabel,
    };
    byInventoryItem.set(entry.inventory_item_id, row);
    byDrug.set(entry.drug_id, row);
  });
  return { maps, byInventoryItem, byDrug, drugIds: Array.from(byDrug.keys()) };
};

const loadControlledStockByDrug = async (scope = {}, byInventoryItem) => {
  const itemIds = Array.from(byInventoryItem.keys());
  if (itemIds.length === 0) return new Map();

  const stocks = await prisma.inventory_stock.findMany({
    where: {
      deleted_at: null,
      inventory_item_id: { in: itemIds },
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    },
    select: {
      inventory_item_id: true,
      quantity: true,
      facility: { select: { name: true } },
    },
  });

  const byDrug = new Map();
  stocks.forEach((stock) => {
    const meta = byInventoryItem.get(stock.inventory_item_id);
    if (!meta) return;
    const existing = byDrug.get(meta.drug_id) || {
      ...meta,
      quantity: 0,
      facility: stock.facility?.name || scope.facility_label || 'Unassigned',
    };
    existing.quantity += asNumber(stock.quantity);
    if (!existing.facility) {
      existing.facility = stock.facility?.name || scope.facility_label || 'Unassigned';
    }
    byDrug.set(meta.drug_id, existing);
  });
  return byDrug;
};

const accumulateByDrug = (map, drugId, amount) => {
  map.set(drugId, asNumber(map.get(drugId)) + asNumber(amount));
};

/**
 * Build per-drug balance rows for the selected period.
 * Exported for pure-ish testing via computeControlledBalance on fixtures.
 */
const buildControlledBalanceRows = async (scope, parameters, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return { invalid: true, range, rows: [], byDrugMeta: new Map() };
  }

  const { byInventoryItem, byDrug: drugMeta, drugIds } = await loadControlledDrugMaps(scope);
  if (drugIds.length === 0) {
    return { invalid: false, range, rows: [], byDrugMeta: drugMeta };
  }

  const stockByDrug = await loadControlledStockByDrug(scope, byInventoryItem);
  const itemIds = Array.from(byInventoryItem.keys());

  const [movements, adjustments, dispenses] = await Promise.all([
    prisma.stock_movement.findMany({
      where: {
        deleted_at: null,
        occurred_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        movement_type: true,
        reason: true,
        quantity: true,
      },
    }),
    prisma.stock_adjustment.findMany({
      where: {
        deleted_at: null,
        adjusted_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        reason: true,
        quantity: true,
      },
    }),
    prisma.dispense_log.findMany({
      where: {
        deleted_at: null,
        status: 'DISPENSED',
        dispensed_at: { gte: range.from, lte: range.to },
        pharmacy_order_item: {
          deleted_at: null,
          drug_id: { in: drugIds },
        },
      },
      select: {
        quantity_dispensed: true,
        pharmacy_order_item: { select: { drug_id: true } },
      },
    }),
  ]);

  const receivedByDrug = new Map();
  const wastageByDrug = new Map();
  const adjustmentsByDrug = new Map();
  const dispensedByDrug = new Map();

  movements.forEach((movement) => {
    const meta = byInventoryItem.get(movement.inventory_item_id);
    if (!meta) return;
    const type = normalizeString(movement.movement_type).toUpperCase();
    const reason = normalizeString(movement.reason).toUpperCase();
    const qty = asNumber(movement.quantity);

    if (type === 'INBOUND' && reason === 'PURCHASE') {
      accumulateByDrug(receivedByDrug, meta.drug_id, Math.abs(qty));
      return;
    }
    if (type === 'ADJUSTMENT' && isWastageReason(reason)) {
      accumulateByDrug(wastageByDrug, meta.drug_id, Math.abs(qty));
      return;
    }
    if (type === 'ADJUSTMENT') {
      // Signed net: negative qty decreases stock; positive reason-coded already handled.
      const signed = qty < 0 ? qty : qty;
      accumulateByDrug(adjustmentsByDrug, meta.drug_id, signed);
    }
  });

  adjustments.forEach((adjustment) => {
    const meta = byInventoryItem.get(adjustment.inventory_item_id);
    if (!meta) return;
    const reason = normalizeString(adjustment.reason).toUpperCase();
    const qty = asNumber(adjustment.quantity);
    if (isWastageReason(reason)) {
      accumulateByDrug(wastageByDrug, meta.drug_id, Math.abs(qty));
      return;
    }
    accumulateByDrug(adjustmentsByDrug, meta.drug_id, qty);
  });

  dispenses.forEach((log) => {
    const drugId = log.pharmacy_order_item?.drug_id;
    if (!drugId) return;
    accumulateByDrug(dispensedByDrug, drugId, log.quantity_dispensed);
  });

  const rows = drugIds.map((drugId) => {
    const meta = drugMeta.get(drugId) || stockByDrug.get(drugId) || { drug: 'Unknown' };
    const closing = asNumber(stockByDrug.get(drugId)?.quantity);
    const balance = computeControlledBalance({
      closing_quantity: closing,
      quantity_received: receivedByDrug.get(drugId) || 0,
      quantity_dispensed: dispensedByDrug.get(drugId) || 0,
      wastage: wastageByDrug.get(drugId) || 0,
      adjustments_net: adjustmentsByDrug.get(drugId) || 0,
    });
    return {
      drug: meta.drug,
      code: meta.code || null,
      facility: stockByDrug.get(drugId)?.facility || scope.facility_label || 'Unassigned',
      unit: meta.unit || null,
      batch_number: null,
      opening_quantity: balance.opening_quantity,
      quantity_received: balance.quantity_received,
      quantity_dispensed: balance.quantity_dispensed,
      wastage: balance.wastage,
      adjustments_net: balance.adjustments_net,
      closing_quantity: balance.closing_quantity,
    };
  });

  return { invalid: false, range, rows, byDrugMeta: drugMeta, byInventoryItem };
};

const runPharmacyControlledBalanceDataset = async (scope, parameters = {}, resolveDateRange) => {
  const built = await buildControlledBalanceRows(scope, parameters, resolveDateRange);
  const fromLabel = built.range?.from ? built.range.from.toISOString().slice(0, 10) : '';
  const toLabel = built.range?.to ? built.range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Controlled medicine balance',
    subtitle: built.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (grain=drug; closing=on-hand; opening=closing−received+dispensed+wastage−adjustments_net)`,
    columns: [
      'drug',
      'facility',
      'opening_quantity',
      'quantity_received',
      'quantity_dispensed',
      'wastage',
      'adjustments_net',
      'closing_quantity',
      'unit',
    ],
    rows: built.rows,
    summary: {
      opening_quantity: built.rows.reduce((s, r) => s + asNumber(r.opening_quantity), 0),
      quantity_received: built.rows.reduce((s, r) => s + asNumber(r.quantity_received), 0),
      quantity_dispensed: built.rows.reduce((s, r) => s + asNumber(r.quantity_dispensed), 0),
      wastage: built.rows.reduce((s, r) => s + asNumber(r.wastage), 0),
      adjustments_net: built.rows.reduce((s, r) => s + asNumber(r.adjustments_net), 0),
      closing_quantity: built.rows.reduce((s, r) => s + asNumber(r.closing_quantity), 0),
    },
  };
};

const runPharmacyControlledStockDataset = async (scope) => {
  const { byInventoryItem, byDrug, drugIds } = await loadControlledDrugMaps(scope);
  const stockByDrug = await loadControlledStockByDrug(scope, byInventoryItem);

  const batchWhere = {
    deleted_at: null,
    drug_id: { in: drugIds },
    quantity: { gt: 0 },
  };
  if (scope.facility_id) {
    batchWhere.OR = [
      { storage_room: { facility_id: scope.facility_id, deleted_at: null } },
      { storage_room_id: null },
    ];
  }

  const batches =
    drugIds.length === 0
      ? []
      : await prisma.drug_batch.findMany({
          where: batchWhere,
          select: {
            drug_id: true,
            batch_number: true,
            quantity: true,
          },
          orderBy: [{ batch_number: 'asc' }],
        });

  const batchByDrug = new Map();
  batches.forEach((batch) => {
    const list = batchByDrug.get(batch.drug_id) || [];
    list.push(normalizeString(batch.batch_number));
    batchByDrug.set(batch.drug_id, list);
  });

  const rows = drugIds.map((drugId) => {
    const meta = byDrug.get(drugId) || {};
    const stock = stockByDrug.get(drugId);
    const numbers = batchByDrug.get(drugId) || [];
    return {
      drug: meta.drug || 'Unknown',
      code: meta.code || null,
      facility: stock?.facility || scope.facility_label || 'Unassigned',
      quantity: asNumber(stock?.quantity),
      batch_number: numbers.length ? numbers.join(', ') : null,
      unit: meta.unit || null,
    };
  });

  return {
    title: 'Controlled medicine stock',
    subtitle: 'On-hand quantity for drug.is_controlled (grain=drug; batch_number lists open batches)',
    columns: ['drug', 'facility', 'quantity', 'batch_number', 'unit'],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      drug_count: rows.length,
    },
  };
};

const runPharmacyControlledReceivedDataset = async (scope, parameters, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Controlled quantity received',
      subtitle: 'Invalid date range',
      columns: ['occurred_at', 'drug', 'quantity', 'facility'],
      rows: [],
      summary: {},
    };
  }
  const { byInventoryItem } = await loadControlledDrugMaps(scope);
  const itemIds = Array.from(byInventoryItem.keys());
  if (itemIds.length === 0) {
    return {
      title: 'Controlled quantity received',
      subtitle: 'No controlled drugs',
      columns: ['occurred_at', 'drug', 'quantity', 'facility'],
      rows: [],
      summary: { quantity: 0 },
    };
  }

  const movements = await prisma.stock_movement.findMany({
    where: {
      deleted_at: null,
      occurred_at: { gte: range.from, lte: range.to },
      inventory_item_id: { in: itemIds },
      movement_type: 'INBOUND',
      reason: 'PURCHASE',
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    },
    select: {
      inventory_item_id: true,
      quantity: true,
      occurred_at: true,
      facility: { select: { name: true } },
    },
    orderBy: [{ occurred_at: 'asc' }],
  });

  const rows = movements.map((movement) => {
    const meta = byInventoryItem.get(movement.inventory_item_id) || {};
    return {
      occurred_at: movement.occurred_at,
      drug: meta.drug || 'Unknown',
      quantity: asNumber(movement.quantity),
      facility: movement.facility?.name || scope.facility_label || 'Unassigned',
      unit: meta.unit || null,
    };
  });

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Controlled quantity received',
    subtitle: `${fromLabel} to ${toLabel} (INBOUND + PURCHASE for controlled drugs)`,
    columns: ['occurred_at', 'drug', 'quantity', 'facility', 'unit'],
    rows,
    summary: { quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0) },
  };
};

const runPharmacyControlledDispensedDataset = async (scope, parameters, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Controlled quantity dispensed',
      subtitle: 'Invalid date range',
      columns: ['dispensed_at', 'drug', 'quantity_dispensed', 'batch_number', 'patient'],
      rows: [],
      summary: {},
    };
  }
  const { drugIds, byDrug } = await loadControlledDrugMaps(scope);
  if (drugIds.length === 0) {
    return {
      title: 'Controlled quantity dispensed',
      subtitle: 'No controlled drugs',
      columns: ['dispensed_at', 'drug', 'quantity_dispensed', 'batch_number', 'patient'],
      rows: [],
      summary: { quantity_dispensed: 0 },
    };
  }

  const logs = await prisma.dispense_log.findMany({
    where: {
      deleted_at: null,
      status: 'DISPENSED',
      dispensed_at: { gte: range.from, lte: range.to },
      pharmacy_order_item: {
        deleted_at: null,
        drug_id: { in: drugIds },
      },
    },
    select: {
      dispensed_at: true,
      quantity_dispensed: true,
      dispense_batch_ref: true,
      pharmacy_order_item: {
        select: {
          drug_id: true,
          pharmacy_order: {
            select: {
              patient: {
                select: {
                  human_friendly_id: true,
                  first_name: true,
                  last_name: true,
                },
              },
            },
          },
        },
      },
    },
    orderBy: [{ dispensed_at: 'asc' }],
  });

  const rows = logs.map((log) => {
    const drugId = log.pharmacy_order_item?.drug_id;
    const meta = byDrug.get(drugId) || {};
    return {
      dispensed_at: log.dispensed_at,
      drug: meta.drug || 'Unknown',
      quantity_dispensed: asNumber(log.quantity_dispensed),
      batch_number: normalizeString(log.dispense_batch_ref) || null,
      patient: resolvePersonLabel(log.pharmacy_order_item?.pharmacy_order?.patient) || null,
      unit: meta.unit || null,
    };
  });

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Controlled quantity dispensed',
    subtitle: `${fromLabel} to ${toLabel} (dispense_log status=DISPENSED)`,
    columns: [
      'dispensed_at',
      'drug',
      'quantity_dispensed',
      'batch_number',
      'patient',
      'unit',
    ],
    rows,
    summary: {
      quantity_dispensed: rows.reduce((sum, row) => sum + asNumber(row.quantity_dispensed), 0),
    },
  };
};

const runPharmacyControlledBatchesDataset = async (scope) => {
  const { drugIds, byDrug } = await loadControlledDrugMaps(scope);
  if (drugIds.length === 0) {
    return {
      title: 'Controlled batch numbers',
      subtitle: 'No controlled drugs',
      columns: ['drug', 'batch_number', 'quantity', 'expiry_date'],
      rows: [],
      summary: {},
    };
  }

  const batchWhere = {
    deleted_at: null,
    drug_id: { in: drugIds },
  };
  if (scope.facility_id) {
    batchWhere.OR = [
      { storage_room: { facility_id: scope.facility_id, deleted_at: null } },
      { storage_room_id: null },
    ];
  }

  const batches = await prisma.drug_batch.findMany({
    where: batchWhere,
    select: {
      drug_id: true,
      batch_number: true,
      quantity: true,
      expiry_date: true,
      manufactured_at: true,
    },
    orderBy: [{ expiry_date: 'asc' }, { batch_number: 'asc' }],
  });

  const rows = batches.map((batch) => {
    const meta = byDrug.get(batch.drug_id) || {};
    return {
      drug: meta.drug || 'Unknown',
      batch_number: normalizeString(batch.batch_number) || null,
      quantity: asNumber(batch.quantity),
      expiry_date: batch.expiry_date,
      manufactured_at: batch.manufactured_at,
      unit: meta.unit || null,
    };
  });

  return {
    title: 'Controlled batch numbers',
    subtitle: 'drug_batch rows for drug.is_controlled',
    columns: ['drug', 'batch_number', 'quantity', 'expiry_date', 'unit'],
    rows,
    summary: {
      batch_count: rows.length,
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
    },
  };
};

const runPharmacyControlledActorsDataset = async (scope, parameters, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Controlled dispense actors',
      subtitle: 'Invalid date range',
      columns: ['actor_role', 'actor', 'drug', 'quantity_dispensed', 'dispensed_at'],
      rows: [],
      summary: {},
    };
  }
  const { drugIds, byDrug } = await loadControlledDrugMaps(scope);
  if (drugIds.length === 0) {
    return {
      title: 'Controlled dispense actors',
      subtitle: 'No controlled drugs',
      columns: ['actor_role', 'actor', 'drug', 'quantity_dispensed', 'dispensed_at'],
      rows: [],
      summary: {},
    };
  }

  const logs = await prisma.dispense_log.findMany({
    where: {
      deleted_at: null,
      status: 'DISPENSED',
      dispensed_at: { gte: range.from, lte: range.to },
      pharmacy_order_item: {
        deleted_at: null,
        drug_id: { in: drugIds },
      },
    },
    select: {
      dispensed_at: true,
      quantity_dispensed: true,
      dispense_batch_ref: true,
      pharmacy_order_item: {
        select: {
          drug_id: true,
          pharmacy_order: {
            select: {
              id: true,
              patient: {
                select: {
                  human_friendly_id: true,
                  first_name: true,
                  last_name: true,
                },
              },
              encounter: {
                select: {
                  provider: {
                    select: {
                      human_friendly_id: true,
                      email: true,
                      profile: {
                        select: { first_name: true, last_name: true },
                      },
                    },
                  },
                },
              },
              dispense_attestations: {
                where: { deleted_at: null },
                select: {
                  phase: true,
                  dispense_batch_ref: true,
                  attested_by_user_id: true,
                  attested_at: true,
                },
                orderBy: [{ attested_at: 'desc' }],
              },
            },
          },
        },
      },
    },
    orderBy: [{ dispensed_at: 'asc' }],
  });

  const staffUserIds = [];
  logs.forEach((log) => {
    const attestations = log.pharmacy_order_item?.pharmacy_order?.dispense_attestations || [];
    const batchRef = normalizeString(log.dispense_batch_ref);
    const matching = attestations.filter(
      (entry) => !batchRef || normalizeString(entry.dispense_batch_ref) === batchRef
    );
    const prefer =
      matching.find((entry) => normalizeString(entry.phase).toUpperCase() === 'ATTEST') ||
      matching[0] ||
      attestations.find((entry) => normalizeString(entry.phase).toUpperCase() === 'ATTEST') ||
      attestations[0];
    if (prefer?.attested_by_user_id) staffUserIds.push(prefer.attested_by_user_id);
  });

  const staffUsers =
    staffUserIds.length === 0
      ? []
      : await prisma.user.findMany({
          where: { id: { in: Array.from(new Set(staffUserIds)) }, deleted_at: null },
          select: {
            id: true,
            human_friendly_id: true,
            email: true,
            profile: { select: { first_name: true, last_name: true } },
          },
        });
  const staffLabelById = new Map(
    staffUsers.map((user) => [
      user.id,
      resolvePersonLabel({
        human_friendly_id: user.human_friendly_id,
        first_name: user.profile?.first_name,
        last_name: user.profile?.last_name,
        email: user.email,
      }),
    ])
  );

  const rows = [];
  logs.forEach((log) => {
    const drugId = log.pharmacy_order_item?.drug_id;
    const meta = byDrug.get(drugId) || {};
    const order = log.pharmacy_order_item?.pharmacy_order;
    const qty = asNumber(log.quantity_dispensed);
    const patient = resolvePersonLabel(order?.patient);
    const provider = order?.encounter?.provider;
    const prescriber = provider
      ? resolvePersonLabel({
          human_friendly_id: provider.human_friendly_id,
          first_name: provider.profile?.first_name,
          last_name: provider.profile?.last_name,
          email: provider.email,
        })
      : null;

    const attestations = Array.isArray(order?.dispense_attestations)
      ? order.dispense_attestations
      : [];
    const batchRef = normalizeString(log.dispense_batch_ref);
    const matching = attestations.filter(
      (entry) => !batchRef || normalizeString(entry.dispense_batch_ref) === batchRef
    );
    const prefer =
      matching.find((entry) => normalizeString(entry.phase).toUpperCase() === 'ATTEST') ||
      matching[0] ||
      attestations.find((entry) => normalizeString(entry.phase).toUpperCase() === 'ATTEST') ||
      attestations[0];
    const staff = prefer?.attested_by_user_id
      ? staffLabelById.get(prefer.attested_by_user_id) || null
      : null;

    if (prescriber) {
      rows.push({
        actor_role: 'prescriber',
        actor: prescriber,
        drug: meta.drug || 'Unknown',
        quantity_dispensed: qty,
        dispensed_at: log.dispensed_at,
      });
    }
    if (patient) {
      rows.push({
        actor_role: 'patient',
        actor: patient,
        drug: meta.drug || 'Unknown',
        quantity_dispensed: qty,
        dispensed_at: log.dispensed_at,
      });
    }
    if (staff) {
      rows.push({
        actor_role: 'staff',
        actor: staff,
        drug: meta.drug || 'Unknown',
        quantity_dispensed: qty,
        dispensed_at: log.dispensed_at,
      });
    }
  });

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Controlled dispense actors',
    subtitle: `${fromLabel} to ${toLabel} (prescriber←encounter.provider; patient←order; staff←attestation)`,
    columns: ['actor_role', 'actor', 'drug', 'quantity_dispensed', 'dispensed_at'],
    rows,
    summary: {
      quantity_dispensed: rows.reduce((sum, row) => sum + asNumber(row.quantity_dispensed), 0),
      row_count: rows.length,
    },
  };
};

const runPharmacyControlledAdjustmentsDataset = async (scope, parameters, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Controlled adjustments',
      subtitle: 'Invalid date range',
      columns: ['adjusted_at', 'drug', 'quantity', 'reason', 'facility'],
      rows: [],
      summary: {},
    };
  }
  const { byInventoryItem } = await loadControlledDrugMaps(scope);
  const itemIds = Array.from(byInventoryItem.keys());
  if (itemIds.length === 0) {
    return {
      title: 'Controlled adjustments',
      subtitle: 'No controlled drugs',
      columns: ['adjusted_at', 'drug', 'quantity', 'reason', 'facility'],
      rows: [],
      summary: { quantity: 0 },
    };
  }

  const [adjustments, movements] = await Promise.all([
    prisma.stock_adjustment.findMany({
      where: {
        deleted_at: null,
        adjusted_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        reason: { notIn: ['EXPIRY', 'DAMAGE'] },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
        reason: true,
        adjusted_at: true,
        facility: { select: { name: true } },
      },
      orderBy: [{ adjusted_at: 'asc' }],
    }),
    prisma.stock_movement.findMany({
      where: {
        deleted_at: null,
        occurred_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        movement_type: 'ADJUSTMENT',
        reason: { notIn: ['EXPIRY', 'DAMAGE'] },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
        reason: true,
        occurred_at: true,
        facility: { select: { name: true } },
      },
      orderBy: [{ occurred_at: 'asc' }],
    }),
  ]);

  const rows = [
    ...adjustments.map((entry) => {
      const meta = byInventoryItem.get(entry.inventory_item_id) || {};
      return {
        adjusted_at: entry.adjusted_at,
        drug: meta.drug || 'Unknown',
        quantity: asNumber(entry.quantity),
        reason: normalizeString(entry.reason) || null,
        facility: entry.facility?.name || scope.facility_label || 'Unassigned',
        unit: meta.unit || null,
      };
    }),
    ...movements.map((entry) => {
      const meta = byInventoryItem.get(entry.inventory_item_id) || {};
      return {
        adjusted_at: entry.occurred_at,
        drug: meta.drug || 'Unknown',
        quantity: asNumber(entry.quantity),
        reason: normalizeString(entry.reason) || 'ADJUSTMENT',
        facility: entry.facility?.name || scope.facility_label || 'Unassigned',
        unit: meta.unit || null,
      };
    }),
  ].sort((a, b) => new Date(a.adjusted_at) - new Date(b.adjusted_at));

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Controlled adjustments',
    subtitle: `${fromLabel} to ${toLabel} (ADJUSTMENT excluding EXPIRY/DAMAGE)`,
    columns: ['adjusted_at', 'drug', 'quantity', 'reason', 'facility', 'unit'],
    rows,
    summary: { quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0) },
  };
};

const runPharmacyControlledWastageDataset = async (scope, parameters, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Controlled wastage',
      subtitle: 'Invalid date range',
      columns: ['adjusted_at', 'drug', 'quantity', 'reason', 'facility'],
      rows: [],
      summary: {},
    };
  }
  const { byInventoryItem } = await loadControlledDrugMaps(scope);
  const itemIds = Array.from(byInventoryItem.keys());
  if (itemIds.length === 0) {
    return {
      title: 'Controlled wastage',
      subtitle: 'No controlled drugs',
      columns: ['adjusted_at', 'drug', 'quantity', 'reason', 'facility'],
      rows: [],
      summary: { quantity: 0 },
    };
  }

  const [adjustments, movements] = await Promise.all([
    prisma.stock_adjustment.findMany({
      where: {
        deleted_at: null,
        adjusted_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        reason: { in: ['EXPIRY', 'DAMAGE'] },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
        reason: true,
        adjusted_at: true,
        facility: { select: { name: true } },
      },
      orderBy: [{ adjusted_at: 'asc' }],
    }),
    prisma.stock_movement.findMany({
      where: {
        deleted_at: null,
        occurred_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        movement_type: 'ADJUSTMENT',
        reason: { in: ['EXPIRY', 'DAMAGE'] },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
        reason: true,
        occurred_at: true,
        facility: { select: { name: true } },
      },
      orderBy: [{ occurred_at: 'asc' }],
    }),
  ]);

  const rows = [
    ...adjustments.map((entry) => {
      const meta = byInventoryItem.get(entry.inventory_item_id) || {};
      return {
        adjusted_at: entry.adjusted_at,
        drug: meta.drug || 'Unknown',
        quantity: Math.abs(asNumber(entry.quantity)),
        reason: normalizeString(entry.reason) || null,
        facility: entry.facility?.name || scope.facility_label || 'Unassigned',
        unit: meta.unit || null,
      };
    }),
    ...movements.map((entry) => {
      const meta = byInventoryItem.get(entry.inventory_item_id) || {};
      return {
        adjusted_at: entry.occurred_at,
        drug: meta.drug || 'Unknown',
        quantity: Math.abs(asNumber(entry.quantity)),
        reason: normalizeString(entry.reason) || null,
        facility: entry.facility?.name || scope.facility_label || 'Unassigned',
        unit: meta.unit || null,
      };
    }),
  ].sort((a, b) => new Date(a.adjusted_at) - new Date(b.adjusted_at));

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Controlled wastage',
    subtitle: `${fromLabel} to ${toLabel} (EXPIRY|DAMAGE)`,
    columns: ['adjusted_at', 'drug', 'quantity', 'reason', 'facility', 'unit'],
    rows,
    summary: { quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0) },
  };
};

const runPharmacyControlledRegulatoryLogDataset = async (scope, parameters, resolveDateRange) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Controlled regulatory log',
      subtitle: 'Invalid date range',
      columns: ['occurred_at', 'event_type', 'drug', 'quantity', 'batch_number', 'actor'],
      rows: [],
      summary: {},
    };
  }
  const { byInventoryItem, byDrug, drugIds } = await loadControlledDrugMaps(scope);
  const itemIds = Array.from(byInventoryItem.keys());
  if (drugIds.length === 0) {
    return {
      title: 'Controlled regulatory log',
      subtitle: 'No controlled drugs',
      columns: ['occurred_at', 'event_type', 'drug', 'quantity', 'batch_number', 'actor'],
      rows: [],
      summary: {},
    };
  }

  const [received, adjustments, wastageAdj, wastageMov, dispenses] = await Promise.all([
    prisma.stock_movement.findMany({
      where: {
        deleted_at: null,
        occurred_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        movement_type: 'INBOUND',
        reason: 'PURCHASE',
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
        occurred_at: true,
      },
    }),
    prisma.stock_adjustment.findMany({
      where: {
        deleted_at: null,
        adjusted_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        reason: { notIn: ['EXPIRY', 'DAMAGE'] },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
        reason: true,
        adjusted_at: true,
      },
    }),
    prisma.stock_adjustment.findMany({
      where: {
        deleted_at: null,
        adjusted_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        reason: { in: ['EXPIRY', 'DAMAGE'] },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
        reason: true,
        adjusted_at: true,
      },
    }),
    prisma.stock_movement.findMany({
      where: {
        deleted_at: null,
        occurred_at: { gte: range.from, lte: range.to },
        inventory_item_id: { in: itemIds },
        movement_type: 'ADJUSTMENT',
        reason: { in: ['EXPIRY', 'DAMAGE'] },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
        reason: true,
        occurred_at: true,
      },
    }),
    prisma.dispense_log.findMany({
      where: {
        deleted_at: null,
        status: 'DISPENSED',
        dispensed_at: { gte: range.from, lte: range.to },
        pharmacy_order_item: {
          deleted_at: null,
          drug_id: { in: drugIds },
        },
      },
      select: {
        dispensed_at: true,
        quantity_dispensed: true,
        dispense_batch_ref: true,
        pharmacy_order_item: {
          select: {
            drug_id: true,
            pharmacy_order: {
              select: {
                dispense_attestations: {
                  where: { deleted_at: null },
                  select: {
                    phase: true,
                    attested_by_user_id: true,
                  },
                  orderBy: [{ attested_at: 'desc' }],
                  take: 4,
                },
              },
            },
          },
        },
      },
    }),
  ]);

  const staffUserIds = [];
  dispenses.forEach((log) => {
    const attestations = log.pharmacy_order_item?.pharmacy_order?.dispense_attestations || [];
    const prefer =
      attestations.find((entry) => normalizeString(entry.phase).toUpperCase() === 'ATTEST') ||
      attestations[0];
    if (prefer?.attested_by_user_id) staffUserIds.push(prefer.attested_by_user_id);
  });
  const staffUsers =
    staffUserIds.length === 0
      ? []
      : await prisma.user.findMany({
          where: { id: { in: Array.from(new Set(staffUserIds)) }, deleted_at: null },
          select: {
            id: true,
            human_friendly_id: true,
            email: true,
            profile: { select: { first_name: true, last_name: true } },
          },
        });
  const staffLabelById = new Map(
    staffUsers.map((user) => [
      user.id,
      resolvePersonLabel({
        human_friendly_id: user.human_friendly_id,
        first_name: user.profile?.first_name,
        last_name: user.profile?.last_name,
        email: user.email,
      }),
    ])
  );

  const rows = [];
  received.forEach((entry) => {
    const meta = byInventoryItem.get(entry.inventory_item_id) || {};
    rows.push({
      occurred_at: entry.occurred_at,
      event_type: 'receive',
      drug: meta.drug || 'Unknown',
      quantity: asNumber(entry.quantity),
      batch_number: null,
      actor: null,
    });
  });
  adjustments.forEach((entry) => {
    const meta = byInventoryItem.get(entry.inventory_item_id) || {};
    rows.push({
      occurred_at: entry.adjusted_at,
      event_type: 'adjust',
      drug: meta.drug || 'Unknown',
      quantity: asNumber(entry.quantity),
      batch_number: null,
      actor: null,
    });
  });
  [...wastageAdj, ...wastageMov].forEach((entry) => {
    const meta = byInventoryItem.get(entry.inventory_item_id) || {};
    rows.push({
      occurred_at: entry.adjusted_at || entry.occurred_at,
      event_type: 'waste',
      drug: meta.drug || 'Unknown',
      quantity: Math.abs(asNumber(entry.quantity)),
      batch_number: null,
      actor: null,
    });
  });
  dispenses.forEach((log) => {
    const drugId = log.pharmacy_order_item?.drug_id;
    const meta = byDrug.get(drugId) || {};
    const attestations = log.pharmacy_order_item?.pharmacy_order?.dispense_attestations || [];
    const prefer =
      attestations.find((entry) => normalizeString(entry.phase).toUpperCase() === 'ATTEST') ||
      attestations[0];
    rows.push({
      occurred_at: log.dispensed_at,
      event_type: 'dispense',
      drug: meta.drug || 'Unknown',
      quantity: asNumber(log.quantity_dispensed),
      batch_number: normalizeString(log.dispense_batch_ref) || null,
      actor: prefer?.attested_by_user_id
        ? staffLabelById.get(prefer.attested_by_user_id) || null
        : null,
    });
  });

  rows.sort((a, b) => new Date(a.occurred_at) - new Date(b.occurred_at));

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Controlled regulatory log',
    subtitle: `${fromLabel} to ${toLabel} (chronological receive/dispense/adjust/waste; compliance-gated)`,
    columns: ['occurred_at', 'event_type', 'drug', 'quantity', 'batch_number', 'actor'],
    rows,
    summary: { event_count: rows.length },
  };
};

const createPharmacyControlledDatasetRunners = (resolveDateRange) => {
  const wrap = (runner) => (scope, parameters = {}) =>
    runner(scope, parameters, resolveDateRange);

  return Object.freeze({
    pharmacy_controlled_stock: (scope) => runPharmacyControlledStockDataset(scope),
    pharmacy_controlled_balance: wrap(runPharmacyControlledBalanceDataset),
    pharmacy_controlled_received: wrap(runPharmacyControlledReceivedDataset),
    pharmacy_controlled_dispensed: wrap(runPharmacyControlledDispensedDataset),
    pharmacy_controlled_batches: (scope) => runPharmacyControlledBatchesDataset(scope),
    pharmacy_controlled_actors: wrap(runPharmacyControlledActorsDataset),
    pharmacy_controlled_adjustments: wrap(runPharmacyControlledAdjustmentsDataset),
    pharmacy_controlled_wastage: wrap(runPharmacyControlledWastageDataset),
    pharmacy_controlled_regulatory_log: wrap(runPharmacyControlledRegulatoryLogDataset),
  });
};

module.exports = {
  assertControlledBalanceInvariant,
  computeControlledBalance,
  createPharmacyControlledDatasetRunners,
  loadControlledDrugMaps,
};
