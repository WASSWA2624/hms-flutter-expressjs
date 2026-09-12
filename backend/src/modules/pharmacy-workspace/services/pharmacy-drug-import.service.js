/**
 * Pharmacy drug import service.
 *
 * Preview parses an uploaded source export (e.g. Medic-ERP) and returns a
 * reviewable plan. Commit re-analyzes the same file against fresh catalog data,
 * rejects the request when the reviewed plan hash no longer matches, and then
 * applies the decisions in one transaction scoped to the user's current
 * facility. Catalog drugs stay tenant-wide; stock and batches land only in that
 * facility.
 */

const crypto = require('crypto');
const path = require('path');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { PERMISSIONS } = require('@config/permissions');
const { ROLES } = require('@config/roles');
const { hasPermission } = require('@lib/billing/pricing-permissions');
const { resolveOperationalFacilityId } = require('@lib/facility-context');
const { findRealtimeRecipientUserIds } = require('@lib/realtime/recipients');
const { emitToUsers, PHARMACY_EVENTS, INVENTORY_EVENTS } = require('@lib/websocket');
const { normalizeText } = require('@lib/tenant/tenant-similarity');
const {
  DRUG_IMPORT_LIMITS,
  resolveDrugImportSource,
  checkTemplateColumns,
} = require('@lib/pharmacy/drug-import/drug-import-sources');
const { readDrugImportWorkbook } = require('@lib/pharmacy/drug-import/drug-import-workbook');
const { toIsoDate } = require('@lib/pharmacy/drug-import/drug-import-values');
const {
  DRUG_IMPORT_ACTIONS,
  DRUG_IMPORT_STOCK_MODES,
  UNLABELED_BATCH_NUMBER,
  buildDrugImportPatch,
  analyzeDrugImport,
  resolveDrugImportDecisions,
  resolveMissingStockDrugs,
} = require('@lib/pharmacy/drug-import/drug-import-analyzer');
const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const { resolveScopedUserContext } = require('@services/pharmacy-workspace/pharmacy.shared');
const { toPublicIdentifier } = require('@services/pharmacy-workspace/pharmacy.serializer');

// A full stock migration is thousands of writes; the default 5s interactive
// transaction timeout would roll every import back.
const DRUG_IMPORT_TRANSACTION_OPTIONS = Object.freeze({
  maxWait: 15 * 1000,
  timeout: 5 * 60 * 1000,
});

const DRUG_IMPORT_RECIPIENT_ROLES = [
  ROLES.PLATFORM_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.PHARMACIST,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.OPERATIONS,
];

const rethrowAsHttpError = (error) => {
  if (error instanceof HttpError) throw error;
  throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
};

const toNumberOrNull = (value) => (value == null ? null : Number(value));

const normalizeCurrency = (value) => {
  const currency = String(value || '').trim().toUpperCase();
  return /^[A-Z]{3}$/.test(currency) ? currency : null;
};

const publicId = (record) =>
  record ? toPublicIdentifier(record.human_friendly_id, record.id) : null;

const assertImportFile = (file) => {
  if (!file?.buffer?.length) {
    throw new HttpError('errors.pharmacy_drug_import.file_required', 400, [{ field: 'file' }]);
  }
  if (path.extname(String(file.originalname || '')).toLowerCase() !== '.xlsx') {
    throw new HttpError('errors.pharmacy_drug_import.invalid_file', 400, [{ field: 'file' }]);
  }
};

const resolveImportTarget = async (user = {}) => {
  const scope = resolveScopedUserContext(user);
  const tenantId = scope.tenant_id;
  if (!tenantId) {
    throw new HttpError('errors.auth.scope_mismatch', 403);
  }

  const facilityId =
    scope.facility_id ||
    (await resolveOperationalFacilityId({ userId: user?.id || null, tenantId }));
  if (!facilityId) {
    throw new HttpError('errors.pharmacy_drug_import.facility_required', 400, [
      { field: 'facility_id' },
    ]);
  }

  const facility = await pharmacyWorkspaceRepository.findFacilityForImport(facilityId, tenantId);
  if (!facility) {
    throw new HttpError('errors.facility.not_found', 404);
  }
  return { tenantId, facility };
};

const toAnalyzerDrug = (drug) => {
  const maps = Array.isArray(drug.inventory_maps) ? drug.inventory_maps : [];
  return {
    id: drug.id,
    human_friendly_id: drug.human_friendly_id,
    name: drug.name,
    generic_name: drug.generic_name,
    brand_name: drug.brand_name,
    code: drug.code,
    form: drug.form,
    strength: drug.strength,
    unit_price: toNumberOrNull(drug.unit_price),
    buy_unit_price: toNumberOrNull(drug.buy_unit_price),
    currency: drug.currency,
    supplier_id: drug.supplier_id,
    supplier_name: drug.supplier?.name || null,
    inventory_item_ids: maps.map((map) => map.inventory_item_id).filter(Boolean),
    facility_quantity: maps.reduce(
      (total, map) =>
        total +
        (map.inventory_item?.stocks || []).reduce(
          (itemTotal, stock) => itemTotal + Number(stock.quantity || 0),
          0
        ),
      0
    ),
  };
};

const buildImportContext = async ({ file, payload = {}, user = {} }) => {
  const source = resolveDrugImportSource(payload.source);
  assertImportFile(file);
  const { tenantId, facility } = await resolveImportTarget(user);

  const workbook = await readDrugImportWorkbook(file.buffer, {
    preferredSheetName: source.preferredSheetName,
    maxRows: DRUG_IMPORT_LIMITS.max_rows,
  });
  const template = checkTemplateColumns(source, workbook.headers);
  const canWritePricing = hasPermission(user, PERMISSIONS.PRICING_PHARMACY_WRITE);

  let plan = null;
  if (!template.missing_columns.length) {
    const drugs = await pharmacyWorkspaceRepository.findDrugsForImport(tenantId, facility.id);
    plan = analyzeDrugImport({
      source,
      rows: workbook.rows,
      existingDrugs: drugs.map(toAnalyzerDrug),
      canWritePricing,
    });
  }

  return { source, tenantId, facility, workbook, template, canWritePricing, plan };
};

const serializeDrug = (drug) =>
  drug
    ? {
        id: publicId(drug),
        name: drug.name || null,
        generic_name: drug.generic_name || null,
        brand_name: drug.brand_name || null,
        code: drug.code || null,
        form: drug.form || null,
        strength: drug.strength || null,
        unit_price: drug.unit_price,
        buy_unit_price: drug.buy_unit_price,
        supplier_name: drug.supplier_name,
        facility_quantity: drug.facility_quantity,
      }
    : null;

const serializeIssue = (issue) => ({
  row_number: issue.row_number ?? null,
  product_key: issue.product_key ?? null,
  severity: issue.severity,
  code: issue.code,
  field: issue.field ?? null,
  params: issue.params || {},
});

const serializeProduct = (product) => ({
  key: product.key,
  name: product.name,
  generic_name: product.generic_name,
  brand_name: product.brand_name,
  form: product.form,
  strength: product.strength,
  unit_price: product.unit_price,
  buy_unit_price: product.buy_unit_price,
  supplier_name: product.supplier_name,
  row_numbers: product.row_numbers,
  total_quantity: product.total_quantity,
  batches: product.batches.map((batch) => ({
    batch_number: batch.batch_number,
    expiry_date: toIsoDate(batch.expiry_date),
    quantity: batch.quantity,
    row_numbers: batch.row_numbers,
  })),
  status: product.status,
  allowed_actions: product.allowed_actions,
  default_action: product.default_action,
  default_target_drug_id: publicId(product.default_target),
  requires_review: product.requires_review,
  match: product.match
    ? { drug: serializeDrug(product.match), changes: product.changes || [] }
    : null,
  candidates: product.candidates.map((candidate) => ({
    drug: serializeDrug(candidate.drug),
    score: candidate.score,
    reasons: candidate.reasons || [],
    changes: candidate.changes || [],
  })),
  issues: product.issues.map(serializeIssue),
});

/**
 * Analyze an uploaded import file without writing anything.
 *
 * @param {Object} params
 * @param {Object} params.file - Multer file (memory storage)
 * @param {Object} params.payload - Validated body: { source }
 * @param {Object} params.user - Authenticated request user
 * @returns {Promise<Object>} Reviewable import plan
 */
const previewDrugImport = async ({ file, payload = {}, user = {} } = {}) => {
  try {
    const { source, facility, workbook, template, canWritePricing, plan } =
      await buildImportContext({ file, payload, user });

    return {
      source: source.id,
      source_label: source.label,
      file_name: file.originalname || null,
      sheet_name: workbook.sheet_name,
      facility: { id: publicId(facility), name: facility.name || null },
      template: {
        columns: source.columns,
        missing_columns: template.missing_columns,
        unexpected_columns: template.unexpected_columns,
        is_valid: template.missing_columns.length === 0,
      },
      limits: DRUG_IMPORT_LIMITS,
      can_write_pricing: canWritePricing,
      can_commit: Boolean(plan && plan.products.length),
      plan_hash: plan?.plan_hash || null,
      summary: plan?.summary || null,
      products: plan ? plan.products.map(serializeProduct) : [],
      issues: plan ? plan.issues.map(serializeIssue) : [],
      stocked_drugs: plan ? plan.stocked_drugs.map(serializeDrug) : [],
    };
  } catch (error) {
    return rethrowAsHttpError(error);
  }
};

const createCounters = () => ({
  created: 0,
  merged: 0,
  updated: 0,
  skipped: 0,
  suppliers_created: 0,
  batches_created: 0,
  batches_updated: 0,
  batches_cleared: 0,
  stock_rows_created: 0,
  stock_rows_adjusted: 0,
  stock_cleared: 0,
  quantity_imported: 0,
});

const resolveSupplierIds = async (tx, { tenantId, entries, suppliers, counters }) => {
  const idsByName = new Map(suppliers.map((supplier) => [normalizeText(supplier.name), supplier.id]));
  for (const { product } of entries) {
    const key = normalizeText(product.supplier_name);
    if (!key || idsByName.has(key)) continue;
    const supplier = await pharmacyWorkspaceRepository.txCreateSupplier(tx, {
      tenant_id: tenantId,
      name: product.supplier_name,
    });
    idsByName.set(key, supplier.id);
    counters.suppliers_created += 1;
  }
  return idsByName;
};

const createInventoryLink = async (tx, { tenantId, drug }) => {
  const inventoryName = drug.brand_name ? `${drug.name} (${drug.brand_name})` : drug.name;
  const inventoryItem = await pharmacyWorkspaceRepository.txCreateInventoryItem(tx, {
    tenant_id: tenantId,
    name: inventoryName.slice(0, 255),
    category: 'MEDICATION',
    sku: drug.code || null,
    unit: 'unit',
  });
  await pharmacyWorkspaceRepository.txCreateDrugInventoryMap(tx, {
    tenant_id: tenantId,
    drug_id: drug.id,
    inventory_item_id: inventoryItem.id,
    is_default: true,
    deduction_factor: 1,
  });
  return inventoryItem.id;
};

const isFacilityBatch = (batch, facilityId) =>
  !batch.storage_room || batch.storage_room.facility_id === facilityId;

// Batches carry no facility of their own; only those shelved in this facility
// (or never shelved) are treated as this facility's stock.
const clearFacilityBatches = async (tx, { drugId, facilityId, keepBatchNumbers = new Set() }) => {
  const batches = await pharmacyWorkspaceRepository.txFindDrugBatchesByDrug(tx, drugId);
  let cleared = 0;
  for (const batch of batches) {
    if (Number(batch.quantity || 0) <= 0 || !isFacilityBatch(batch, facilityId)) continue;
    if (keepBatchNumbers.has(String(batch.batch_number || '').trim().toUpperCase())) continue;
    await pharmacyWorkspaceRepository.txUpdateDrugBatch(tx, batch.id, { quantity: 0 });
    cleared += 1;
  }
  return cleared;
};

const applyStock = async (tx, { drugId, inventoryItemId, product, isNewDrug, ctx }) => {
  const { facilityId, stockMode, counters, occurredAt } = ctx;
  const replace = stockMode === DRUG_IMPORT_STOCK_MODES.REPLACE;
  counters.quantity_imported += product.total_quantity;

  const stock = await pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility(
    tx,
    inventoryItemId,
    facilityId
  );
  const currentQuantity = Number(stock?.quantity || 0);
  const nextQuantity = replace ? product.total_quantity : currentQuantity + product.total_quantity;

  if (!stock && nextQuantity > 0) {
    await pharmacyWorkspaceRepository.txCreateInventoryStock(tx, {
      inventory_item_id: inventoryItemId,
      facility_id: facilityId,
      quantity: nextQuantity,
      reorder_level: 0,
    });
    await pharmacyWorkspaceRepository.txCreateStockMovement(tx, {
      inventory_item_id: inventoryItemId,
      facility_id: facilityId,
      movement_type: 'INBOUND',
      reason: 'PURCHASE',
      quantity: nextQuantity,
      occurred_at: occurredAt,
    });
    counters.stock_rows_created += 1;
  } else if (stock && nextQuantity !== currentQuantity) {
    const receivesStock = !replace && nextQuantity > currentQuantity;
    await pharmacyWorkspaceRepository.txUpdateInventoryStock(tx, stock.id, {
      quantity: nextQuantity,
    });
    await pharmacyWorkspaceRepository.txCreateStockMovement(tx, {
      inventory_item_id: inventoryItemId,
      facility_id: facilityId,
      movement_type: receivesStock ? 'INBOUND' : 'ADJUSTMENT',
      reason: receivesStock ? 'PURCHASE' : 'OTHER',
      quantity: Math.abs(nextQuantity - currentQuantity),
      occurred_at: occurredAt,
    });
    counters.stock_rows_adjusted += 1;
  }

  const importedBatchNumbers = new Set();
  for (const batch of product.batches) {
    const batchNumber = batch.batch_number || UNLABELED_BATCH_NUMBER;
    importedBatchNumbers.add(batchNumber.toUpperCase());

    const existing = isNewDrug
      ? null
      : await pharmacyWorkspaceRepository.txFindDrugBatchByDrugAndNumber(tx, drugId, batchNumber);
    if (existing) {
      const existingQuantity = Number(existing.quantity || 0);
      const quantity = replace ? batch.quantity : existingQuantity + batch.quantity;
      const patch = {};
      if (quantity !== existingQuantity) patch.quantity = quantity;
      if (batch.expiry_date && toIsoDate(batch.expiry_date) !== toIsoDate(existing.expiry_date)) {
        patch.expiry_date = batch.expiry_date;
      }
      if (Object.keys(patch).length) {
        await pharmacyWorkspaceRepository.txUpdateDrugBatch(tx, existing.id, patch);
        counters.batches_updated += 1;
      }
    } else if (batch.quantity > 0 || batch.expiry_date) {
      await pharmacyWorkspaceRepository.txCreateDrugBatch(tx, {
        drug_id: drugId,
        batch_number: batchNumber,
        expiry_date: batch.expiry_date,
        quantity: batch.quantity,
      });
      counters.batches_created += 1;
    }
  }

  if (replace && !isNewDrug) {
    counters.batches_cleared += await clearFacilityBatches(tx, {
      drugId,
      facilityId,
      keepBatchNumbers: importedBatchNumbers,
    });
  }
};

const applyProductDecision = async (tx, { entry, ctx }) => {
  const { product, action, target } = entry;
  const { tenantId, canWritePricing, currency, supplierIdsByName, counters, changes } = ctx;
  const supplierId = supplierIdsByName.get(normalizeText(product.supplier_name)) || null;

  if (action === DRUG_IMPORT_ACTIONS.CREATE) {
    const drug = await pharmacyWorkspaceRepository.txCreateDrug(tx, {
      tenant_id: tenantId,
      name: product.name,
      generic_name: product.generic_name,
      brand_name: product.brand_name,
      form: product.form,
      strength: product.strength,
      supplier_id: supplierId,
      ...buildDrugImportPatch(
        product,
        {},
        { overwrite: true, canWritePricing, currency }
      ),
    });
    const inventoryItemId = await createInventoryLink(tx, { tenantId, drug });
    counters.created += 1;
    changes.created.push(drug);
    await applyStock(tx, { drugId: drug.id, inventoryItemId, product, isNewDrug: true, ctx });
    return;
  }

  const overwrite = action === DRUG_IMPORT_ACTIONS.UPDATE;
  const patch = buildDrugImportPatch(product, target, {
    overwrite,
    canWritePricing,
    currency,
    supplierId,
  });
  let drug = target;
  if (Object.keys(patch).length) {
    drug = await pharmacyWorkspaceRepository.txUpdateDrug(tx, target.id, patch);
    changes.updated.push({
      drug,
      before: Object.fromEntries(Object.keys(patch).map((field) => [field, target[field] ?? null])),
      after: patch,
    });
  }
  counters[overwrite ? 'updated' : 'merged'] += 1;

  const inventoryMap = await pharmacyWorkspaceRepository.txFindInventoryMapByDrug(
    tx,
    target.id,
    tenantId
  );
  const inventoryItemId =
    inventoryMap?.inventory_item_id ||
    (await createInventoryLink(tx, { tenantId, drug: { ...target, ...patch } }));
  await applyStock(tx, { drugId: target.id, inventoryItemId, product, isNewDrug: false, ctx });
};

const clearMissingDrugStock = async (tx, { drug, ctx }) => {
  const { facilityId, counters, changes, occurredAt } = ctx;
  let cleared = false;
  for (const inventoryItemId of drug.inventory_item_ids) {
    const stock = await pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility(
      tx,
      inventoryItemId,
      facilityId
    );
    const quantity = Number(stock?.quantity || 0);
    if (!stock || quantity <= 0) continue;
    await pharmacyWorkspaceRepository.txUpdateInventoryStock(tx, stock.id, { quantity: 0 });
    await pharmacyWorkspaceRepository.txCreateStockMovement(tx, {
      inventory_item_id: inventoryItemId,
      facility_id: facilityId,
      movement_type: 'ADJUSTMENT',
      reason: 'OTHER',
      quantity,
      occurred_at: occurredAt,
    });
    cleared = true;
  }
  counters.batches_cleared += await clearFacilityBatches(tx, { drugId: drug.id, facilityId });
  if (cleared) {
    counters.stock_cleared += 1;
    changes.cleared.push(drug);
  }
};

const publishDrugImportRealtime = async ({ tenantId, facilityId, actorUserId, summary }) => {
  try {
    const recipients = await findRealtimeRecipientUserIds({
      tenantId,
      facilityId,
      roles: DRUG_IMPORT_RECIPIENT_ROLES,
      extraUserIds: [actorUserId],
    });
    if (!recipients.length) return;

    const payload = {
      tenant_id: tenantId,
      facility_id: facilityId,
      actor_user_id: actorUserId || null,
      action: 'IMPORT',
      resource_type: 'drug',
      occurred_at: new Date().toISOString(),
      target_path: '/pharmacy?section=catalog',
      summary,
    };
    emitToUsers(recipients, PHARMACY_EVENTS.PHARMACY_CATALOG_UPDATED, payload);
    emitToUsers(recipients, INVENTORY_EVENTS.INVENTORY_STOCK_UPDATED, { ...payload, stocks: [] });
  } catch (_error) {
    // Realtime delivery must not fail a committed import.
  }
};

/**
 * Apply a reviewed import to the catalog and the current facility's stock.
 *
 * @param {Object} params
 * @param {Object} params.file - Multer file (memory storage), the same file that was previewed
 * @param {Object} params.payload - Validated body: source, plan_hash, decisions, stock_mode,
 *   clear_missing_stock, confirm_review, currency
 * @param {string|null} params.userId
 * @param {string|null} params.ipAddress
 * @param {Object} params.user - Authenticated request user
 * @returns {Promise<Object>} Import summary
 * @throws {HttpError} 409 when the catalog or file changed since preview
 */
const commitDrugImport = async ({
  file,
  payload = {},
  userId = null,
  ipAddress = null,
  user = {},
} = {}) => {
  try {
    const { source, tenantId, facility, template, canWritePricing, plan } =
      await buildImportContext({ file, payload, user });

    if (template.missing_columns.length) {
      throw new HttpError('errors.pharmacy_drug_import.template_mismatch', 400, [
        { field: 'file', missing_columns: template.missing_columns },
      ]);
    }
    if (!payload.plan_hash || payload.plan_hash !== plan.plan_hash) {
      throw new HttpError('errors.pharmacy_drug_import.stale_preview', 409, [
        { field: 'plan_hash' },
      ]);
    }

    const resolved = resolveDrugImportDecisions(plan.products, payload.decisions);
    if (resolved.some((entry) => entry.product.requires_review) && payload.confirm_review !== true) {
      throw new HttpError('errors.pharmacy_drug_import.review_required', 400, [
        { field: 'confirm_review' },
      ]);
    }

    const stockMode =
      payload.stock_mode === DRUG_IMPORT_STOCK_MODES.ADD
        ? DRUG_IMPORT_STOCK_MODES.ADD
        : DRUG_IMPORT_STOCK_MODES.REPLACE;
    const clearMissingStock = payload.clear_missing_stock === true;
    if (clearMissingStock && stockMode !== DRUG_IMPORT_STOCK_MODES.REPLACE) {
      throw new HttpError('errors.pharmacy_drug_import.clear_missing_requires_replace', 400, [
        { field: 'clear_missing_stock' },
      ]);
    }

    const entries = resolved.filter((entry) => entry.action !== DRUG_IMPORT_ACTIONS.SKIP);
    const missingDrugs = clearMissingStock
      ? resolveMissingStockDrugs(plan.stocked_drugs, resolved)
      : [];
    if (!entries.length && !missingDrugs.length) {
      throw new HttpError('errors.pharmacy_drug_import.nothing_to_import', 400, [
        { field: 'decisions' },
      ]);
    }

    const suppliers = await pharmacyWorkspaceRepository.findSuppliersForImport(tenantId);
    const counters = createCounters();
    counters.skipped = resolved.length - entries.length;
    const changes = { created: [], updated: [], cleared: [] };

    await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
      const ctx = {
        tenantId,
        facilityId: facility.id,
        canWritePricing,
        currency: canWritePricing ? normalizeCurrency(payload.currency) : null,
        stockMode,
        counters,
        changes,
        occurredAt: new Date(),
        supplierIdsByName: await resolveSupplierIds(tx, { tenantId, entries, suppliers, counters }),
      };
      for (const entry of entries) {
        await applyProductDecision(tx, { entry, ctx });
      }
      for (const drug of missingDrugs) {
        await clearMissingDrugStock(tx, { drug, ctx });
      }
    }, DRUG_IMPORT_TRANSACTION_OPTIONS);

    const importId = crypto.randomUUID();
    createAuditLog({
      tenant_id: tenantId,
      facility_id: facility.id,
      user_id: userId,
      action: 'CREATE',
      entity: 'drug_import',
      entity_id: importId,
      diff: {
        metadata: {
          source: source.id,
          file_name: file.originalname || null,
          stock_mode: stockMode,
          clear_missing_stock: clearMissingStock,
          summary: counters,
          created_drug_ids: changes.created.map(publicId),
          updated_drugs: changes.updated.map(({ drug, before, after }) => ({
            id: publicId(drug),
            before,
            after,
          })),
          cleared_drug_ids: changes.cleared.map(publicId),
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    publishDrugImportRealtime({
      tenantId,
      facilityId: facility.id,
      actorUserId: userId,
      summary: counters,
    });

    return {
      import_id: importId,
      source: source.id,
      facility: { id: publicId(facility), name: facility.name || null },
      stock_mode: stockMode,
      summary: counters,
    };
  } catch (error) {
    return rethrowAsHttpError(error);
  }
};

module.exports = {
  previewDrugImport,
  commitDrugImport,
};
