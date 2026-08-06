const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  mapClinicalOrderBillingFields,
  mapCatalogUnitPriceFields} = require('@lib/billing/clinical-request-billing');
const { resolveOrderLocation } = require('@services/pharmacy-workspace/pharmacy.shared');
const { mapStorageLocationFields } = require('@services/pharmacy-workspace/pharmacy-storage.service');

const toText = (value) => (value == null ? '' : String(value).trim());

const toPublicIdentifier = (...candidates) => {
  let uuidFallback = null;
  for (const candidate of candidates) {
    const normalized = toText(candidate);
    if (!normalized) continue;
    // Prefer human-friendly IDs; fall back to UUID so records without HFID
    // are still usable in the pharmacy UI (nested/createMany writes can omit HFID).
    if (isUuidLike(normalized)) {
      if (!uuidFallback) uuidFallback = normalized;
      continue;
    }
    return normalized;
  }
  return uuidFallback;
};

const toIsoDateTime = (value) => {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
};

const toDisplayName = (...segments) => {
  const value = segments.map(toText).filter(Boolean).join(' ').trim();
  return value || null;
};

const toFiniteNumber = (value, fallback = 0) => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  return numeric;
};

const resolveStockStatus = (quantityValue, reorderValue) => {
  const quantity = toFiniteNumber(quantityValue, 0);
  const reorderLevel = toFiniteNumber(reorderValue, 0);

  if (quantity <= 0) return 'OUT_OF_STOCK';
  if (reorderLevel > 0 && quantity <= reorderLevel) return 'LOW_STOCK';
  if (reorderLevel > 0 && quantity <= reorderLevel * 2) return 'ALMOST_OUT_OF_STOCK';
  return 'IN_STOCK';
};

const resolveAggregateStockStatus = (statuses = []) => {
  const ranking = {
    OUT_OF_STOCK: 4,
    LOW_STOCK: 3,
    ALMOST_OUT_OF_STOCK: 2,
    IN_STOCK: 1};

  return statuses.reduce((current, status) => {
    const normalized = toText(status).toUpperCase() || 'IN_STOCK';
    return ranking[normalized] > ranking[current] ? normalized : current;
  }, 'IN_STOCK');
};

const resolveOrderPriority = (items = []) => {
  const hasStat = items.some((item) => toText(item?.frequency).toUpperCase() === 'STAT');
  if (hasStat) return 'STAT';
  return 'ROUTINE';
};

const mapInventoryItemRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);

  return {
    id: publicId,
    display_id: publicId,
    tenant_id: toPublicIdentifier(record.tenant?.human_friendly_id, record.tenant_id),
    name: toText(record.name) || null,
    category: toText(record.category).toUpperCase() || null,
    sku: toText(record.sku) || null,
    unit: toText(record.unit) || null,
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const resolveExpiryAlertStatus = (expiryDate, expiringWithinDays = 30) => {
  if (!expiryDate) return null;
  const parsed = expiryDate instanceof Date ? expiryDate : new Date(expiryDate);
  if (Number.isNaN(parsed.getTime())) return null;
  const now = new Date();
  if (parsed.getTime() < now.getTime()) return 'EXPIRED';
  const horizon = new Date(now);
  horizon.setDate(horizon.getDate() + Number(expiringWithinDays || 30));
  if (parsed.getTime() <= horizon.getTime()) return 'EXPIRING_SOON';
  return null;
};

const buildBatchMetaByInventoryItemId = (maps = [], batches = [], expiringWithinDays = 30) => {
  const batchesByDrugId = batches.reduce((acc, batch) => {
    if (!batch?.drug_id) return acc;
    if (!acc.has(batch.drug_id)) acc.set(batch.drug_id, []);
    acc.get(batch.drug_id).push(batch);
    return acc;
  }, new Map());

  const metaByInventoryItemId = new Map();
  maps.forEach((mapRow) => {
    const drugBatches = batchesByDrugId.get(mapRow.drug_id) || [];
    if (!drugBatches.length) return;

    const activeBatches = drugBatches.filter((batch) => Number(batch.quantity || 0) > 0);
    const datedBatches = activeBatches
      .filter((batch) => batch.expiry_date)
      .sort((left, right) => new Date(left.expiry_date) - new Date(right.expiry_date));

    const nextExpiryBatch = datedBatches[0] || null;
    const nextExpiry = nextExpiryBatch?.expiry_date
      ? toIsoDateTime(nextExpiryBatch.expiry_date)
      : null;

    let expiryAlertStatus = null;
    for (const batch of datedBatches) {
      const leadDays =
        batch.expiry_alert_lead_days != null
          ? Number(batch.expiry_alert_lead_days)
          : expiringWithinDays;
      const status = resolveExpiryAlertStatus(batch.expiry_date, leadDays);
      if (status === 'EXPIRED') {
        expiryAlertStatus = 'EXPIRED';
        break;
      }
      if (status === 'EXPIRING_SOON') {
        expiryAlertStatus = 'EXPIRING_SOON';
      }
    }

    const storageBatch =
      activeBatches.find((batch) => batch.storage_shelf_id || batch.storage_room_id) ||
      nextExpiryBatch ||
      activeBatches[0] ||
      null;

    metaByInventoryItemId.set(mapRow.inventory_item_id, {
      batch_count: activeBatches.length,
      next_expiry: nextExpiry,
      expiry_alert_status: expiryAlertStatus,
      ...mapStorageLocationFields(storageBatch?.storage_room, storageBatch?.storage_shelf)});
  });

  return metaByInventoryItemId;
};

const mapInventoryStockRecord = (record, batchMeta = null) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const inventoryItem = mapInventoryItemRecord(record.inventory_item);

  return {
    id: publicId,
    display_id: publicId,
    inventory_item_id: toPublicIdentifier(inventoryItem?.id, record.inventory_item_id),
    inventory_item: inventoryItem,
    facility_id: toPublicIdentifier(record.facility?.human_friendly_id, record.facility_id),
    facility_name: toText(record.facility?.name) || null,
    quantity: Number(record.quantity || 0),
    reorder_level: Number(record.reorder_level || 0),
    pending_stock: false,
    stock_status: resolveStockStatus(record.quantity, record.reorder_level),
    low_stock:
      Number.isFinite(Number(record.reorder_level)) && Number(record.quantity) <= Number(record.reorder_level),
    batch_count: Number(batchMeta?.batch_count || 0),
    next_expiry: batchMeta?.next_expiry || null,
    expiry_alert_status: batchMeta?.expiry_alert_status || null,
    storage_room_id: batchMeta?.storage_room_id || null,
    storage_room_label: batchMeta?.storage_room_label || null,
    storage_shelf_id: batchMeta?.storage_shelf_id || null,
    storage_shelf_code: batchMeta?.storage_shelf_code || null,
    storage_location_label: batchMeta?.storage_location_label || null,
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapDrugRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const inventoryMaps = Array.isArray(record.inventory_maps) ? record.inventory_maps : [];
  const stockRows = [];
  const stockStatuses = [];

  const stockMappings = inventoryMaps
    .map((mapping) => {
      const inventoryItem = mapInventoryItemRecord(mapping.inventory_item);
      const stocks = Array.isArray(mapping.inventory_item?.stocks)
        ? mapping.inventory_item.stocks
            .map((stock) =>
              mapInventoryStockRecord({
                ...stock,
                inventory_item: mapping.inventory_item})
            )
            .filter(Boolean)
        : [];

      stocks.forEach((stock) => {
        stockRows.push(stock);
        stockStatuses.push(stock.stock_status);
      });

      return {
        id: toPublicIdentifier(mapping.human_friendly_id, mapping.id),
        display_id: toPublicIdentifier(mapping.human_friendly_id, mapping.id),
        inventory_item_id: toPublicIdentifier(
          inventoryItem?.id,
          mapping.inventory_item?.human_friendly_id,
          mapping.inventory_item_id
        ),
        is_default: Boolean(mapping.is_default),
        deduction_factor: toFiniteNumber(mapping.deduction_factor, 1),
        inventory_item: inventoryItem,
        stocks};
    })
    .filter(Boolean);

  const quantityOnHand = stockRows.reduce(
    (total, stock) => total + toFiniteNumber(stock.quantity, 0),
    0
  );
  const stockStatus = stockRows.length
    ? resolveAggregateStockStatus(stockStatuses)
    : resolveStockStatus(quantityOnHand, 0);

  return {
    id: publicId,
    display_id: publicId,
    tenant_id: toPublicIdentifier(record.tenant?.human_friendly_id, record.tenant_id),
    name: toText(record.name) || null,
    brand_name: toText(record.brand_name) || null,
    generic_name: toText(record.generic_name) || null,
    code: toText(record.code) || null,
    form: toText(record.form) || null,
    strength: toText(record.strength) || null,
    ...mapCatalogUnitPriceFields({
      unit_price: record.pharmacy_unit_price ?? record.unit_price,
      currency: record.pharmacy_currency ?? record.currency}),
    pharmacy_unit_price:
      mapCatalogUnitPriceFields({
        unit_price: record.pharmacy_unit_price ?? record.unit_price,
        currency: record.pharmacy_currency ?? record.currency}).unit_price || null,
    pharmacy_currency: toText(record.pharmacy_currency ?? record.currency).toUpperCase() || null,
    facility_unit_price:
      mapCatalogUnitPriceFields({
        unit_price: record.facility_unit_price,
        currency: record.facility_currency}).unit_price || null,
    facility_currency: toText(record.facility_currency).toUpperCase() || null,
    quantity_on_hand: quantityOnHand,
    available_quantity: quantityOnHand,
    stock_level: quantityOnHand,
    stock_status: stockStatus,
    low_stock: stockStatuses.some((status) =>
      ['LOW_STOCK', 'OUT_OF_STOCK'].includes(toText(status).toUpperCase())
    ) || stockStatus === 'OUT_OF_STOCK',
    pending_stock: false,
    stock_mappings: stockMappings,
    stock_rows: stockRows,
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapDispenseLogRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);

  return {
    id: publicId,
    display_id: publicId,
    pharmacy_order_item_id: toPublicIdentifier(
      record.pharmacy_order_item?.human_friendly_id,
      record.pharmacy_order_item_id
    ),
    dispense_batch_ref: toText(record.dispense_batch_ref) || null,
    status: toText(record.status).toUpperCase() || null,
    quantity_dispensed: Number(record.quantity_dispensed || 0),
    dispensed_at: toIsoDateTime(record.dispensed_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapPharmacyAttestationRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);

  return {
    id: publicId,
    display_id: publicId,
    pharmacy_order_id: toPublicIdentifier(
      record.pharmacy_order?.human_friendly_id,
      record.pharmacy_order_id
    ),
    dispense_batch_ref: toText(record.dispense_batch_ref) || null,
    phase: toText(record.phase).toUpperCase() || null,
    attested_by_user_id: toPublicIdentifier(record.attested_by_user_id),
    attested_role: toText(record.attested_role) || null,
    statement: toText(record.statement) || null,
    reason: toText(record.reason) || null,
    attested_at: toIsoDateTime(record.attested_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const computeItemDispenseMetrics = (item) => {
  const logs = Array.isArray(item?.dispense_logs) ? item.dispense_logs : [];

  const dispensedQuantity = logs
    .filter((entry) => String(entry.status || '').toUpperCase() === 'DISPENSED')
    .reduce((sum, entry) => sum + Number(entry.quantity_dispensed || 0), 0);
  const returnedQuantity = logs
    .filter((entry) => String(entry.status || '').toUpperCase() === 'RETURNED')
    .reduce((sum, entry) => sum + Number(entry.quantity_dispensed || 0), 0);
  const pendingQuantity = logs
    .filter((entry) => String(entry.status || '').toUpperCase() === 'PENDING')
    .reduce((sum, entry) => sum + Number(entry.quantity_dispensed || 0), 0);

  const prescribedQuantity = Number(item?.quantity || 0);
  const netDispensedQuantity = Math.max(0, dispensedQuantity - returnedQuantity);
  // Pending prepare batches are already reserved and cannot be prepared again.
  const remainingQuantity = Math.max(
    0,
    prescribedQuantity - netDispensedQuantity - pendingQuantity
  );

  return {
    prescribedQuantity,
    dispensedQuantity,
    returnedQuantity,
    pendingQuantity,
    netDispensedQuantity,
    remainingQuantity};
};

const mapDrugInventoryMapRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);

  return {
    id: publicId,
    display_id: publicId,
    drug_id: toPublicIdentifier(record.drug?.human_friendly_id, record.drug_id),
    inventory_item_id: toPublicIdentifier(
      record.inventory_item?.human_friendly_id,
      record.inventory_item_id
    ),
    is_default: Boolean(record.is_default),
    deduction_factor: toFiniteNumber(record.deduction_factor, 1),
    inventory_item: mapInventoryItemRecord(record.inventory_item)};
};

const mapPharmacyOrderItemRecord = (record, options = {}) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const metrics = computeItemDispenseMetrics(record);
  const inventoryMaps = Array.isArray(record.drug?.inventory_maps)
    ? record.drug.inventory_maps.map(mapDrugInventoryMapRecord).filter(Boolean)
    : [];

  const drugDisplayName = [
    toText(record.drug?.name),
    toText(record.drug?.strength),
    toText(record.drug?.form)]
    .filter(Boolean)
    .join(' ') || toText(record.drug?.code) || null;

  const offering = record.drug_id ? options.offeringsByDrugId?.[record.drug_id] : null;
  const pharmacyPriceFields = mapCatalogUnitPriceFields({
    unit_price: record.drug?.unit_price,
    currency: record.drug?.currency});
  const facilityPriceFields = mapCatalogUnitPriceFields({
    unit_price: offering?.unit_price,
    currency: offering?.currency || record.drug?.currency});

  return {
    id: publicId,
    display_id: publicId,
    pharmacy_order_id: toPublicIdentifier(
      record.pharmacy_order?.human_friendly_id,
      record.pharmacy_order_id
    ),
    drug_id: toPublicIdentifier(record.drug?.human_friendly_id, record.drug_id),
    drug_display_name: drugDisplayName,
    drug_code: toText(record.drug?.code) || null,
    drug_form: toText(record.drug?.form) || null,
    drug_strength: toText(record.drug?.strength) || null,
    dosage: toText(record.dosage) || null,
    dose_amount: record.dose_amount == null ? null : toFiniteNumber(record.dose_amount, null),
    dose_unit: toText(record.dose_unit) || null,
    frequency: toText(record.frequency).toUpperCase() || null,
    route: toText(record.route).toUpperCase() || null,
    duration_value: record.duration_value == null ? null : toFiniteNumber(record.duration_value, null),
    duration_unit: toText(record.duration_unit) || null,
    instructions: toText(record.instructions) || null,
    custom_prescription: toText(record.custom_prescription) || null,
    status: toText(record.status).toUpperCase() || null,
    quantity: toFiniteNumber(record.quantity, 0),
    quantity_unit: toText(record.quantity_unit) || null,
    quantity_prescribed: metrics.prescribedQuantity,
    quantity_dispensed: metrics.netDispensedQuantity,
    quantity_pending: metrics.pendingQuantity,
    quantity_returned: metrics.returnedQuantity,
    quantity_remaining: metrics.remainingQuantity,
    dispense_logs: (record.dispense_logs || []).map(mapDispenseLogRecord).filter(Boolean),
    stock_mappings: inventoryMaps,
    default_stock_mapping: inventoryMaps.find((entry) => entry.is_default) || inventoryMaps[0] || null,
    pharmacy_unit_price: pharmacyPriceFields.unit_price || null,
    pharmacy_price: pharmacyPriceFields.price || null,
    pharmacy_currency: pharmacyPriceFields.currency || null,
    facility_unit_price: facilityPriceFields.unit_price || null,
    facility_price: facilityPriceFields.price || null,
    facility_currency: facilityPriceFields.currency || null,
    is_offered_at_facility: Boolean(offering?.is_active),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at)};
};

const mapPharmacyOrderRecord = (record, options = {}) => {
  if (!record || typeof record !== 'object') return null;
  const { includeChildren = true, offeringsByDrugId = {} } = options;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);

  const items = includeChildren && Array.isArray(record.items)
    ? record.items
        .map((entry) =>
          mapPharmacyOrderItemRecord(
            { ...entry, pharmacy_order: record },
            { offeringsByDrugId }
          )
        )
        .filter(Boolean)
    : [];
  const attestations = includeChildren && Array.isArray(record.dispense_attestations)
    ? record.dispense_attestations.map(mapPharmacyAttestationRecord).filter(Boolean)
    : [];

  const totals = items.reduce(
    (acc, item) => {
      acc.prescribed += Number(item.quantity_prescribed || 0);
      acc.dispensed += Number(item.quantity_dispensed || 0);
      acc.pending += Number(item.quantity_pending || 0);
      acc.returned += Number(item.quantity_returned || 0);
      acc.remaining += Number(item.quantity_remaining || 0);
      return acc;
    },
    { prescribed: 0, dispensed: 0, pending: 0, returned: 0, remaining: 0 }
  );

  const attestationByBatch = new Map();
  attestations.forEach((entry) => {
    const batchRef = entry.dispense_batch_ref;
    if (!batchRef) return;
    const current = attestationByBatch.get(batchRef) || {};
    current[entry.phase] = entry;
    attestationByBatch.set(batchRef, current);
  });

  const pendingAttestationBatches = Array.from(attestationByBatch.entries())
    .filter(([ phases]) => phases.PREPARE && !phases.ATTEST)
    .map(([batchRef, phases]) => ({
      dispense_batch_ref: batchRef,
      prepared_at: phases.PREPARE?.attested_at || null,
      prepared_by_role: phases.PREPARE?.attested_role || null}));

  return {
    id: publicId,
    display_id: publicId,
    encounter_id: toPublicIdentifier(record.encounter?.human_friendly_id, record.encounter_id),
    encounter_type: toText(record.encounter?.encounter_type).toUpperCase() || null,
    location: resolveOrderLocation(record.encounter?.encounter_type),
    patient_id: toPublicIdentifier(record.patient?.human_friendly_id, record.patient_id),
    patient_display_name:
      toDisplayName(record.patient?.first_name, record.patient?.last_name) ||
      (record.patient_id ? null : 'Walk-in'),
    order_source: record.encounter_id ? 'CLINICAL' : 'PHARMACY',
    priority: resolveOrderPriority(record.items || []),
    status: toText(record.status).toUpperCase() || null,
    ordered_at: toIsoDateTime(record.ordered_at),
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
    item_count: items.length,
    quantity_prescribed_total: totals.prescribed,
    quantity_dispensed_total: totals.dispensed,
    quantity_pending_total: totals.pending,
    quantity_returned_total: totals.returned,
    quantity_remaining_total: totals.remaining,
    pending_attestation_batch_count: pendingAttestationBatches.length,
    pending_attestation_batches: pendingAttestationBatches,
    items,
    dispense_attestations: attestations,
    ...mapClinicalOrderBillingFields(record)};
};

const mapPharmacyOrderWorkflowRecord = (record, options = {}) => {
  const order = mapPharmacyOrderRecord(record, { includeChildren: true, ...options });
  if (!order) return null;

  const timeline = [
    {
      id: 'order-placed',
      type: 'ORDER_PLACED',
      at: order.ordered_at || order.created_at,
      label_key: 'pharmacy.workbench.timeline.orderPlaced',
      label_params: {}}];

  // Group dispense logs by batch + status so one timeline row opens one batch.
  const dispenseBatches = new Map();
  order.items.forEach((item, itemIndex) => {
    const medication =
      item.drug_display_name || item.display_id || String(itemIndex + 1);
    (item.dispense_logs || []).forEach((log, logIndex) => {
      const status = toText(log.status).toUpperCase() || 'UPDATED';
      const batchRef = toText(log.dispense_batch_ref) || null;
      const logId = log.id || `${item.id}-${logIndex}`;
      const bucketKey = batchRef
        ? `batch:${batchRef}|${status}`
        : `log:${logId}|${status}`;
      const existing = dispenseBatches.get(bucketKey);
      const at = log.dispensed_at || log.updated_at || log.created_at;
      if (!existing) {
        dispenseBatches.set(bucketKey, {
          id: batchRef
            ? `dispense-batch-${batchRef}-${status}`
            : `dispense-log-${logId}`,
          type: `DISPENSE_${status}`,
          at,
          batch: batchRef,
          log_id: batchRef ? null : logId,
          status,
          medications: [medication],
          line_count: 1});
        return;
      }
      existing.line_count += 1;
      existing.medications.push(medication);
      const existingAt = Date.parse(existing.at || '');
      const nextAt = Date.parse(at || '');
      if (Number.isFinite(nextAt) && (!Number.isFinite(existingAt) || nextAt > existingAt)) {
        existing.at = at;
      }
    });
  });

  for (const batch of dispenseBatches.values()) {
    const isSingle = batch.line_count === 1;
    timeline.push({
      id: batch.id,
      type: batch.type,
      at: batch.at,
      label_key: isSingle
        ? 'pharmacy.workbench.timeline.medicationDispenseEvent'
        : 'pharmacy.workbench.timeline.dispenseBatchEvent',
      label_params: {
        medication: isSingle ? batch.medications[0] : null,
        medication_count: batch.line_count,
        status: batch.status,
        batch: batch.batch,
        log_id: batch.log_id}});
  }

  order.dispense_attestations.forEach((attestation, index) => {
    timeline.push({
      id: `dispense-attestation-${attestation.id || index}`,
      type: `DISPENSE_${toText(attestation.phase).toUpperCase() || 'ATTESTED'}`,
      at: attestation.attested_at || attestation.created_at,
      label_key: 'pharmacy.workbench.timeline.dispenseAttestationEvent',
      label_params: {
        phase: toText(attestation.phase).toUpperCase() || 'ATTESTED',
        batch: attestation.dispense_batch_ref || null}});
  });

  timeline.sort((a, b) => {
    const left = Date.parse(a.at || '');
    const right = Date.parse(b.at || '');
    if (!Number.isFinite(left) && !Number.isFinite(right)) return 0;
    if (!Number.isFinite(left)) return 1;
    if (!Number.isFinite(right)) return -1;
    return left - right;
  });

  const hasPendingAttestation = Number(order.pending_attestation_batch_count || 0) > 0;

  return {
    order,
    items: order.items,
    attestations: order.dispense_attestations,
    timeline,
    next_actions: {
      can_prepare_dispense: ['ORDERED', 'PARTIALLY_DISPENSED'].includes(order.status) && !hasPendingAttestation,
      can_attest_dispense: ['ORDERED', 'PARTIALLY_DISPENSED'].includes(order.status) && hasPendingAttestation,
      can_cancel: ['ORDERED', 'PARTIALLY_DISPENSED'].includes(order.status),
      can_return: ['DISPENSED', 'PARTIALLY_DISPENSED'].includes(order.status),
      can_adjust_inventory: true}};
};

module.exports = {
  toPublicIdentifier,
  toIsoDateTime,
  resolveStockStatus,
  resolveExpiryAlertStatus,
  buildBatchMetaByInventoryItemId,
  mapInventoryItemRecord,
  mapInventoryStockRecord,
  mapDrugRecord,
  mapDispenseLogRecord,
  mapPharmacyAttestationRecord,
  mapPharmacyOrderItemRecord,
  mapPharmacyOrderRecord,
  mapPharmacyOrderWorkflowRecord};
