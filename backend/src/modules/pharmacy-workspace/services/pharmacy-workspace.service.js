
const crypto = require('crypto');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { normalizeIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const prisma = require('@prisma/client');
const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const pharmacyOrderService = require('@services/pharmacy-order/pharmacy-order.service');
const { emitToUsers, PHARMACY_EVENTS, INVENTORY_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');
const {
  PHARMACY_ORDER_WITH_RELATIONS_INCLUDE,
  INVENTORY_STOCK_WITH_RELATIONS_INCLUDE,
  INVENTORY_ITEM_PUBLIC_SELECT,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  toDateOrNull,
  applyDateRangeFilter,
  resolveScopedUserContext,
  buildTenantScopeWhere,
  buildPatientScopeWhere,
  buildEncounterScopeWhere,
  buildDrugScopeWhere,
  buildInventoryItemScopeWhere,
  buildOrderScopeWhere,
  buildOrderItemScopeWhere,
  buildInventoryStockScopeWhere,
  matchesOrderScope,
  matchesInventoryStockScope,
} = require('@services/pharmacy-workspace/pharmacy.shared');
const {
  toPublicIdentifier,
  mapPharmacyOrderRecord,
  mapPharmacyOrderWorkflowRecord,
  mapInventoryStockRecord,
  mapDrugRecord,
} = require('@services/pharmacy-workspace/pharmacy.serializer');

const PHARMACY_RECIPIENT_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.PHARMACIST,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.OPERATIONS,
];

const LEGACY_ROUTE_CONFIG = Object.freeze({
  'pharmacy-orders': {
    model: 'pharmacy_order',
    resource: 'orders',
    route: '/pharmacy/orders',
  },
  'pharmacy-order-items': {
    model: 'pharmacy_order_item',
    resource: 'order-items',
    route: '/pharmacy/order-items',
  },
  'dispense-logs': {
    model: 'dispense_log',
    resource: 'dispense-logs',
    route: '/pharmacy/dispense-logs',
  },
  'inventory-items': {
    model: 'inventory_item',
    resource: 'inventory-items',
    route: '/pharmacy?panel=inventory&item=',
  },
  'inventory-stocks': {
    model: 'inventory_stock',
    resource: 'inventory-stock',
    route: '/pharmacy?panel=inventory&stock=',
  },
  'stock-movements': {
    model: 'stock_movement',
    resource: 'stock-movements',
    route: '/pharmacy?panel=inventory&movement=',
  },
  drugs: {
    model: 'drug',
    resource: 'drugs',
    route: '/pharmacy/drugs',
  },
});

const appendAnd = (where, clause) => {
  if (!clause || typeof clause !== 'object') return;
  if (!Array.isArray(where.AND)) where.AND = [];
  where.AND.push(clause);
};

const hasKeys = (value) => Boolean(value && typeof value === 'object' && Object.keys(value).length);

const STOCK_STATUS = Object.freeze({
  IN_STOCK: 'IN_STOCK',
  ALMOST_OUT_OF_STOCK: 'ALMOST_OUT_OF_STOCK',
  LOW_STOCK: 'LOW_STOCK',
  OUT_OF_STOCK: 'OUT_OF_STOCK',
});

const resolveStockStatus = (quantityValue, reorderValue) => {
  const quantity = Number(quantityValue || 0);
  const reorderLevel = Number(reorderValue || 0);

  if (quantity <= 0) return STOCK_STATUS.OUT_OF_STOCK;
  if (reorderLevel > 0 && quantity <= reorderLevel) return STOCK_STATUS.LOW_STOCK;
  if (reorderLevel > 0 && quantity <= reorderLevel * 2) {
    return STOCK_STATUS.ALMOST_OUT_OF_STOCK;
  }
  return STOCK_STATUS.IN_STOCK;
};

const summarizeStockMetrics = (records = []) =>
  records.reduce(
    (summary, record) => {
      const status = resolveStockStatus(record?.quantity, record?.reorder_level);
      summary.total_stock_rows += 1;
      if (status === STOCK_STATUS.OUT_OF_STOCK) summary.out_of_stock_rows += 1;
      if (status === STOCK_STATUS.LOW_STOCK) summary.low_stock_rows += 1;
      if (status === STOCK_STATUS.ALMOST_OUT_OF_STOCK) summary.almost_out_of_stock_rows += 1;
      return summary;
    },
    {
      total_stock_rows: 0,
      low_stock_rows: 0,
      almost_out_of_stock_rows: 0,
      pending_stock_rows: 0,
      out_of_stock_rows: 0,
    }
  );

const buildDrugStockInclude = (scope = {}) => ({
  inventory_maps: {
    where: { deleted_at: null },
    orderBy: [{ is_default: 'desc' }, { created_at: 'asc' }],
    include: {
      inventory_item: {
        select: {
          ...INVENTORY_ITEM_PUBLIC_SELECT,
          stocks: {
            where: {
              deleted_at: null,
              ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
            },
            include: {
              facility: {
                select: {
                  id: true,
                  human_friendly_id: true,
                  name: true,
                },
              },
            },
          },
        },
      },
    },
  },
});

const resolveScopedOrderId = async (identifier, scope) =>
  resolveModelIdOrThrow({
    identifier,
    model: 'pharmacy_order',
    where: {
      deleted_at: null,
      ...buildOrderScopeWhere(scope),
    },
    errorKey: 'errors.pharmacy_order.not_found',
  });

const resolveScopedInventoryItemId = async (identifier, scope) =>
  resolveModelIdOrThrow({
    identifier,
    model: 'inventory_item',
    where: {
      deleted_at: null,
      ...buildInventoryItemScopeWhere(scope),
    },
    errorKey: 'errors.inventory_item.not_found',
  });

const resolveScopedFacilityId = async (identifier, scope, allowNull = false) =>
  resolveModelIdOrThrow({
    identifier: scope?.facility_id || identifier || null,
    model: 'facility',
    where: {
      deleted_at: null,
      ...buildTenantScopeWhere(scope),
    },
    errorKey: 'errors.facility.not_found',
    allowNull,
  });

const ensureScopedOrderRecord = (orderRecord, scope) => {
  if (!orderRecord || !matchesOrderScope(orderRecord, scope)) {
    throw new HttpError('errors.pharmacy_order.not_found', 404);
  }
  return orderRecord;
};

const ensureScopedInventoryStockRecord = (stockRecord, scope) => {
  if (!stockRecord || !matchesInventoryStockScope(stockRecord, scope)) {
    throw new HttpError('errors.inventory_stock.not_found', 404);
  }
  return stockRecord;
};

const buildLegacyScopeWhere = (model, scope) => {
  switch (model) {
    case 'pharmacy_order':
      return buildOrderScopeWhere(scope);
    case 'pharmacy_order_item':
      return buildOrderItemScopeWhere(scope);
    case 'dispense_log': {
      const orderItemScope = buildOrderItemScopeWhere(scope);
      return hasKeys(orderItemScope)
        ? {
            pharmacy_order_item: orderItemScope,
          }
        : {};
    }
    case 'inventory_item':
      return buildInventoryItemScopeWhere(scope);
    case 'inventory_stock':
      return buildInventoryStockScopeWhere(scope);
    case 'stock_movement': {
      const where = {};
      const inventoryItemScope = buildInventoryItemScopeWhere(scope);
      if (hasKeys(inventoryItemScope)) {
        where.inventory_item = inventoryItemScope;
      }
      if (!scope?.can_manage_all_tenants && scope?.facility_id) {
        where.facility_id = scope.facility_id;
      }
      return where;
    }
    case 'drug':
      return buildDrugScopeWhere(scope);
    default:
      return {};
  }
};

const assertTransition = (condition, details = {}) => {
  if (condition) return;
  throw new HttpError('errors.pharmacy_workspace.invalid_transition', 400, [details]);
};

const buildDispenseBatchRef = () => {
  const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
  const entropy = crypto.randomBytes(3).toString('hex').toUpperCase();
  return `DSP${stamp}${entropy}`;
};

const normalizeBatchRef = (value) => {
  const normalized = String(value || '').trim().toUpperCase();
  if (!normalized) return null;
  return normalized.slice(0, 64);
};

const resolveRoleRecipients = async ({ tenantId, facilityId = null }) => {
  if (!tenantId || !prisma?.user_role?.findMany) return [];

  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      role: {
        name: { in: PHARMACY_RECIPIENT_ROLES },
        deleted_at: null,
      },
      ...(facilityId ? { OR: [{ facility_id: null }, { facility_id: facilityId }] } : {}),
    },
    select: {
      user_id: true,
    },
  });

  return rows.map((item) => item.user_id).filter(Boolean);
};

const buildPharmacyRealtimePayload = ({
  workflow,
  action,
  resourceType = null,
  resourceId = null,
  batchRef = null,
}) => {
  const order = workflow?.order || null;
  const orderId = String(order?.id || '').trim() || null;
  const patientId = String(order?.patient_id || '').trim() || null;
  const nowIso = new Date().toISOString();

  return {
    order_id: orderId,
    order_public_id: orderId,
    patient_id: patientId,
    patient_public_id: patientId,
    patient_display_name: order?.patient_display_name || null,
    status: order?.status || null,
    action: String(action || 'UPDATED').trim().toUpperCase(),
    resource_type: resourceType,
    resource_id: resourceId,
    dispense_batch_ref: batchRef || null,
    occurred_at: nowIso,
    target_path: orderId ? `/pharmacy?id=${encodeURIComponent(orderId)}` : '/pharmacy',
    workflow,
  };
};

const publishPharmacyRealtimeUpdates = async ({
  workflow,
  orderRecord,
  actorUserId = null,
  action,
  resourceType = null,
  resourceId = null,
  batchRef = null,
  stockRecords = [],
}) => {
  try {
    const tenantId = orderRecord?.patient?.tenant_id || null;
    if (!tenantId) return;

    const facilityId = orderRecord?.patient?.facility_id || null;
    const recipientUserIds = await resolveRoleRecipients({ tenantId, facilityId });
    const recipients = recipientUserIds.filter((userId) => userId && userId !== actorUserId);
    if (!recipients.length) return;

    const workflowPayload = buildPharmacyRealtimePayload({
      workflow,
      action,
      resourceType,
      resourceId,
      batchRef,
    });

    emitToUsers(recipients, PHARMACY_EVENTS.PHARMACY_WORKSPACE_UPDATED, workflowPayload);

    emitToUsers(recipients, PHARMACY_EVENTS.PHARMACY_ORDER_UPDATED, {
      order_id: workflowPayload.order_id,
      order_public_id: workflowPayload.order_public_id,
      patient_id: workflowPayload.patient_id,
      patient_public_id: workflowPayload.patient_public_id,
      status: workflowPayload.status,
      action: workflowPayload.action,
      resource_type: workflowPayload.resource_type,
      resource_id: workflowPayload.resource_id,
      dispense_batch_ref: workflowPayload.dispense_batch_ref,
      occurred_at: workflowPayload.occurred_at,
      target_path: workflowPayload.target_path,
    });

    if (!Array.isArray(stockRecords) || !stockRecords.length) return;

    const stockPayload = stockRecords.map((stock) => mapInventoryStockRecord(stock)).filter(Boolean);
    if (!stockPayload.length) return;

    emitToUsers(recipients, INVENTORY_EVENTS.INVENTORY_STOCK_UPDATED, {
      action: workflowPayload.action,
      order_id: workflowPayload.order_id,
      order_public_id: workflowPayload.order_public_id,
      dispense_batch_ref: workflowPayload.dispense_batch_ref,
      occurred_at: workflowPayload.occurred_at,
      stocks: stockPayload,
    });
  } catch (_error) {
    // realtime delivery must not block business mutations
  }
};

const computeItemDispensedMetrics = (item) => {
  const logs = Array.isArray(item?.dispense_logs) ? item.dispense_logs : [];

  const dispensed = logs
    .filter((entry) => String(entry.status || '').toUpperCase() === 'DISPENSED')
    .reduce((sum, entry) => sum + Number(entry.quantity_dispensed || 0), 0);
  const returned = logs
    .filter((entry) => String(entry.status || '').toUpperCase() === 'RETURNED')
    .reduce((sum, entry) => sum + Number(entry.quantity_dispensed || 0), 0);
  const pending = logs
    .filter((entry) => String(entry.status || '').toUpperCase() === 'PENDING')
    .reduce((sum, entry) => sum + Number(entry.quantity_dispensed || 0), 0);

  const prescribed = Number(item?.quantity || 0);
  const netDispensed = Math.max(0, dispensed - returned);
  const remaining = Math.max(0, prescribed - netDispensed);

  return {
    prescribed,
    dispensed,
    returned,
    pending,
    netDispensed,
    remaining,
  };
};

const resolveOrderItemByIdentifier = (orderRecord, identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;

  const upper = normalized.toUpperCase();
  const items = Array.isArray(orderRecord?.items) ? orderRecord.items : [];

  return (
    items.find((item) => {
      if (!item) return false;
      if (isUuidLike(normalized)) {
        return String(item.id || '').toLowerCase() === normalized.toLowerCase();
      }

      const friendly = String(item.human_friendly_id || '').trim().toUpperCase();
      return friendly && friendly === upper;
    }) || null
  );
};

const resolveInventoryMapForItem = async ({
  tx,
  item,
  tenantId,
  inventoryItemIdentifier = null,
}) => {
  const mappings = Array.isArray(item?.drug?.inventory_maps) ? item.drug.inventory_maps : [];

  if (inventoryItemIdentifier) {
    const normalized = normalizeIdentifier(inventoryItemIdentifier);
    const resolved = mappings.find((entry) => {
      if (!entry) return false;
      if (isUuidLike(normalized)) {
        return String(entry.inventory_item_id || '').toLowerCase() === normalized.toLowerCase();
      }
      return (
        String(entry.inventory_item?.human_friendly_id || '').trim().toUpperCase() ===
        String(normalized || '').toUpperCase()
      );
    });

    if (resolved) return resolved;

    const inventoryItemId = await resolveModelIdOrThrow({
      identifier: inventoryItemIdentifier,
      model: 'inventory_item',
      where: {
        deleted_at: null,
        ...(tenantId ? { tenant_id: tenantId } : {}),
      },
      errorKey: 'errors.inventory_item.not_found',
    });

    const explicitMap = await pharmacyWorkspaceRepository.txFindInventoryMapByDrugAndItem(
      tx,
      item.drug_id,
      inventoryItemId,
      tenantId
    );

    if (explicitMap) return explicitMap;
  }

  if (mappings.length) {
    return mappings.find((entry) => Boolean(entry.is_default)) || mappings[0];
  }

  return pharmacyWorkspaceRepository.txFindInventoryMapByDrug(tx, item.drug_id, tenantId);
};

const normalizeStockDeductionQuantity = (requestedQuantity, deductionFactor) => {
  const quantity = Number(requestedQuantity || 0);
  const factor = Number(deductionFactor || 1);
  const normalizedFactor = Number.isFinite(factor) && factor > 0 ? factor : 1;
  const raw = quantity * normalizedFactor;
  const rounded = Math.ceil(raw);
  return Number.isFinite(rounded) ? rounded : 0;
};

const rollupOrderStatus = (orderRecord) => {
  const items = Array.isArray(orderRecord?.items) ? orderRecord.items : [];

  if (!items.length) {
    return 'ORDERED';
  }

  let allComplete = true;
  let anyDispensed = false;

  for (const item of items) {
    const metrics = computeItemDispensedMetrics(item);
    if (metrics.netDispensed > 0) anyDispensed = true;
    if (metrics.netDispensed < metrics.prescribed) allComplete = false;
  }

  if (allComplete) return 'DISPENSED';
  if (anyDispensed) return 'PARTIALLY_DISPENSED';
  return 'ORDERED';
};

const listPendingAttestationBatchRefs = (orderRecord) => {
  const attestations = Array.isArray(orderRecord?.dispense_attestations)
    ? orderRecord.dispense_attestations
    : [];

  const phasesByBatch = new Map();
  attestations.forEach((entry) => {
    const batchRef = normalizeBatchRef(entry?.dispense_batch_ref);
    const phase = String(entry?.phase || '').trim().toUpperCase();
    if (!batchRef || !phase) return;

    const current = phasesByBatch.get(batchRef) || new Set();
    current.add(phase);
    phasesByBatch.set(batchRef, current);
  });

  return Array.from(phasesByBatch.entries())
    .filter(([, phases]) => phases.has('PREPARE') && !phases.has('ATTEST'))
    .map(([batchRef]) => batchRef);
};

const buildWorkbenchOrderWhere = async (filters = {}, scope, options = {}) => {
  const includeSearch = options.includeSearch !== false;
  const where = {
    ...buildOrderScopeWhere(scope),
  };

  if (filters.patient_id) {
    where.patient_id = await resolveModelIdOrThrow({
      identifier: filters.patient_id,
      model: 'patient',
      where: {
        deleted_at: null,
        ...buildPatientScopeWhere(scope),
      },
      errorKey: 'errors.patient.not_found',
    });
  }

  if (filters.encounter_id) {
    where.encounter_id = await resolveModelIdOrThrow({
      identifier: filters.encounter_id,
      model: 'encounter',
      where: {
        deleted_at: null,
        ...buildEncounterScopeWhere(scope),
      },
      errorKey: 'errors.encounter.not_found',
    });
  }

  if (filters.status) {
    where.status = filters.status;
  }

  applyDateRangeFilter(where, 'ordered_at', filters.from, filters.to);

  const searchTerm = normalizeSearchTerm(filters.search);
  if (includeSearch && searchTerm) {
    appendAnd(where, {
      OR: [
        { human_friendly_id: { contains: searchTerm.upper } },
        { patient: { human_friendly_id: { contains: searchTerm.upper } } },
        { patient: { first_name: { contains: searchTerm.raw } } },
        { patient: { last_name: { contains: searchTerm.raw } } },
        { encounter: { human_friendly_id: { contains: searchTerm.upper } } },
        { items: { some: { human_friendly_id: { contains: searchTerm.upper } } } },
        { items: { some: { drug: { human_friendly_id: { contains: searchTerm.upper } } } } },
        { items: { some: { drug: { name: { contains: searchTerm.raw } } } } },
        { items: { some: { drug: { code: { contains: searchTerm.raw } } } } },
        { items: { some: { dispense_logs: { some: { dispense_batch_ref: { contains: searchTerm.upper } } } } } },
      ],
    });
  }

  return where;
};

const buildInventoryStockWhere = async (filters = {}, scope, options = {}) => {
  const includeSearch = options.includeSearch !== false;
  const where = {
    ...buildInventoryStockScopeWhere(scope),
  };

  if (filters.facility_id) {
    where.facility_id = await resolveScopedFacilityId(filters.facility_id, scope);
  } else if (scope?.facility_id && !scope?.can_manage_all_tenants) {
    where.facility_id = scope.facility_id;
  }

  if (filters.inventory_item_id) {
    where.inventory_item_id = await resolveScopedInventoryItemId(filters.inventory_item_id, scope);
  }

  if (filters.low_stock_only === true) {
    where.quantity = {
      lte: prisma.inventory_stock.fields.reorder_level,
    };
  }

  const searchTerm = normalizeSearchTerm(filters.search);
  if (includeSearch && searchTerm) {
    appendAnd(where, {
      OR: [
        { human_friendly_id: { contains: searchTerm.upper } },
        { inventory_item: { human_friendly_id: { contains: searchTerm.upper } } },
        { inventory_item: { name: { contains: searchTerm.raw } } },
        { inventory_item: { sku: { contains: searchTerm.raw } } },
      ],
    });
  }

  return where;
};

const buildDrugWhere = (filters = {}, scope, options = {}) => {
  const includeSearch = options.includeSearch !== false;
  const where = {
    ...buildDrugScopeWhere(scope),
  };

  if (filters.name) where.name = { contains: String(filters.name).trim() };
  if (filters.code) where.code = { contains: String(filters.code).trim() };
  if (filters.form) where.form = { contains: String(filters.form).trim() };
  if (filters.strength) where.strength = { contains: String(filters.strength).trim() };

  const searchTerm = normalizeSearchTerm(filters.search);
  if (includeSearch && searchTerm) {
    appendAnd(where, {
      OR: [
        { human_friendly_id: { contains: searchTerm.upper } },
        { name: { contains: searchTerm.raw } },
        { code: { contains: searchTerm.raw } },
        { form: { contains: searchTerm.raw } },
        { strength: { contains: searchTerm.raw } },
      ],
    });
  }

  return where;
};

const buildWorkbenchSummary = async (summaryWhere) => {
  const [
    totalOrders,
    orderedQueue,
    partiallyDispensedQueue,
    dispensedOrders,
    cancelledOrders,
    preparedAttestations,
    completedAttestations,
  ] = await Promise.all([
    pharmacyWorkspaceRepository.countOrders(summaryWhere),
    pharmacyWorkspaceRepository.countOrders({ ...summaryWhere, status: 'ORDERED' }),
    pharmacyWorkspaceRepository.countOrders({ ...summaryWhere, status: 'PARTIALLY_DISPENSED' }),
    pharmacyWorkspaceRepository.countOrders({ ...summaryWhere, status: 'DISPENSED' }),
    pharmacyWorkspaceRepository.countOrders({ ...summaryWhere, status: 'CANCELLED' }),
    pharmacyWorkspaceRepository.countDispenseAttestations({
      phase: 'PREPARE',
      pharmacy_order: {
        deleted_at: null,
        ...summaryWhere,
      },
    }),
    pharmacyWorkspaceRepository.countDispenseAttestations({
      phase: 'ATTEST',
      pharmacy_order: {
        deleted_at: null,
        ...summaryWhere,
      },
    }),
  ]);

  return {
    total_orders: totalOrders,
    ordered_queue: orderedQueue,
    partially_dispensed_queue: partiallyDispensedQueue,
    dispensed_orders: dispensedOrders,
    cancelled_orders: cancelledOrders,
    pending_attestations: Math.max(0, preparedAttestations - completedAttestations),
  };
};

const getPharmacyWorkbench = async (filters, page, limit, sortBy, order, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { ordered_at: 'desc' };

    const [where, summaryWhere] = await Promise.all([
      buildWorkbenchOrderWhere(filters, scope, { includeSearch: true }),
      buildWorkbenchOrderWhere(filters, scope, { includeSearch: false }),
    ]);

    const [worklistRecords, total, summary] = await Promise.all([
      pharmacyWorkspaceRepository.findManyOrders(
        where,
        skip,
        limit,
        orderBy,
        PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
      ),
      pharmacyWorkspaceRepository.countOrders(where),
      buildWorkbenchSummary(summaryWhere),
    ]);

    return {
      summary,
      worklist: worklistRecords.map((record) => mapPharmacyOrderRecord(record)).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getPharmacyOrderWorkflow = async (identifier, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const orderId = await resolveScopedOrderId(identifier, scope);

    const orderRecord = ensureScopedOrderRecord(
      await pharmacyWorkspaceRepository.findOrderById(
        orderId,
        PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
      ),
      scope
    );

    return mapPharmacyOrderWorkflowRecord(orderRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const searchDrugs = async (filters, page, limit, sortBy, order, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const skip = (page - 1) * limit;
    const safeSortBy = ['name', 'code', 'form', 'strength', 'updated_at', 'created_at'].includes(sortBy)
      ? sortBy
      : 'name';
    const orderBy = { [safeSortBy]: order || 'asc' };
    const where = buildDrugWhere(filters, scope, { includeSearch: true });

    const [records, total] = await Promise.all([
      pharmacyWorkspaceRepository.findManyDrugs(
        where,
        skip,
        limit,
        orderBy,
        buildDrugStockInclude(scope)
      ),
      pharmacyWorkspaceRepository.countDrugs(where),
    ]);

    const stockStatus = String(filters?.stock_status || '').trim().toUpperCase();
    const drugs = records
      .map((record) => mapDrugRecord(record))
      .filter(Boolean)
      .filter((drug) => !stockStatus || drug.stock_status === stockStatus);

    return {
      summary: {
        total_drugs: total,
        returned_drugs: drugs.length,
      },
      drugs,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createPharmacyOrder = async (payload = {}, userId, ipAddress, user = {}) => {
  try {
    const created = await pharmacyOrderService.createPharmacyOrder(
      payload,
      userId,
      ipAddress,
      user
    );
    const scope = resolveScopedUserContext(user);
    const orderId = await resolveScopedOrderId(created?.id || created?.display_id, scope);
    const orderRecord = ensureScopedOrderRecord(
      await pharmacyWorkspaceRepository.findOrderById(
        orderId,
        PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
      ),
      scope
    );
    const workflow = mapPharmacyOrderWorkflowRecord(orderRecord);

    publishPharmacyRealtimeUpdates({
      workflow,
      orderRecord,
      actorUserId: userId || null,
      action: 'CREATE_ORDER',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
    }).catch(() => {});

    const orderSummary = await buildWorkbenchSummary(
      await buildWorkbenchOrderWhere({}, scope, { includeSearch: false })
    );

    return {
      workflow,
      order_summary: orderSummary,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const prepareDispense = async (identifier, payload = {}, userId, userRole, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const orderId = await resolveScopedOrderId(identifier, scope);

    const batchRef = normalizeBatchRef(payload.dispense_batch_ref) || buildDispenseBatchRef();

    const mutation = await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
      const order = ensureScopedOrderRecord(
        await pharmacyWorkspaceRepository.txFindOrderById(
          tx,
          orderId,
          PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
        ),
        scope
      );

      assertTransition(['ORDERED', 'PARTIALLY_DISPENSED'].includes(order.status), {
        from: order.status,
        to: 'PREPARE_DISPENSE',
      });

      const existingPrepare = await pharmacyWorkspaceRepository.txFindDispenseAttestation(
        tx,
        order.id,
        batchRef,
        'PREPARE'
      );
      const existingAttest = await pharmacyWorkspaceRepository.txFindDispenseAttestation(
        tx,
        order.id,
        batchRef,
        'ATTEST'
      );

      if (existingPrepare || existingAttest) {
        const refreshedOrder = await pharmacyWorkspaceRepository.txFindOrderById(
          tx,
          order.id,
          PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
        );
        return {
          order: refreshedOrder,
          batchRef,
          prepareAttestation: existingPrepare,
        };
      }

      const pendingBatchRefs = listPendingAttestationBatchRefs(order).filter(
        (entry) => entry !== batchRef
      );
      assertTransition(pendingBatchRefs.length === 0, {
        reason: 'pending_attestation_exists',
        requested_batch_ref: batchRef,
        pending_batch_refs: pendingBatchRefs,
      });

      const explicitLines = Array.isArray(payload.items) && payload.items.length ? payload.items : null;
      const sourceItems = explicitLines
        ? explicitLines
        : (order.items || []).map((item) => ({
            order_item_id: item.human_friendly_id || item.id,
            quantity: computeItemDispensedMetrics(item).remaining,
          }));

      const targetLines = [];
      for (const line of sourceItems) {
        const orderItem = resolveOrderItemByIdentifier(order, line.order_item_id);
        if (!orderItem) {
          throw new HttpError('errors.pharmacy_order_item.not_found', 404);
        }

        const quantity = Number(line.quantity || 0);
        assertTransition(Number.isFinite(quantity) && quantity > 0, {
          reason: 'invalid_quantity',
          order_item_id: line.order_item_id,
        });

        const metrics = computeItemDispensedMetrics(orderItem);
        assertTransition(quantity <= metrics.remaining, {
          reason: 'quantity_exceeds_remaining',
          order_item_id: line.order_item_id,
          remaining: metrics.remaining,
          requested: quantity,
        });

        targetLines.push({
          orderItem,
          quantity,
        });
      }

      if (!targetLines.length) {
        throw new HttpError('errors.pharmacy_workspace.nothing_to_dispense', 400);
      }

      for (const line of targetLines) {
        await pharmacyWorkspaceRepository.txCreateDispenseLog(tx, {
          pharmacy_order_item_id: line.orderItem.id,
          dispense_batch_ref: batchRef,
          status: 'PENDING',
          quantity_dispensed: line.quantity,
        });
      }

      const prepareAttestation = await pharmacyWorkspaceRepository.txCreateDispenseAttestation(tx, {
        pharmacy_order_id: order.id,
        dispense_batch_ref: batchRef,
        phase: 'PREPARE',
        attested_by_user_id: userId,
        attested_role: userRole || null,
        statement: payload.statement || null,
        reason: payload.reason || null,
        ip_address: ipAddress || null,
        attested_at: new Date(),
      });

      const refreshedOrder = await pharmacyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        order: refreshedOrder,
        batchRef,
        prepareAttestation,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'PREPARE_DISPENSE',
      entity: 'pharmacy_order',
      entity_id: mutation.order?.id,
      diff: {
        metadata: {
          dispense_batch_ref: mutation.batchRef,
          line_count: Array.isArray(payload.items) ? payload.items.length : null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapPharmacyOrderWorkflowRecord(mutation.order);

    publishPharmacyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'PREPARE_DISPENSE',
      resourceType: 'dispense_batch',
      resourceId: mutation.batchRef,
      batchRef: mutation.batchRef,
    }).catch(() => {});

    const orderSummary = await buildWorkbenchSummary(
      await buildWorkbenchOrderWhere({}, scope, { includeSearch: false })
    );

    return {
      workflow,
      dispense_batch_ref: mutation.batchRef,
      order_summary: orderSummary,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const attestDispense = async (identifier, payload = {}, userId, userRole, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const orderId = await resolveScopedOrderId(identifier, scope);

    const batchRef = normalizeBatchRef(payload.dispense_batch_ref);
    if (!batchRef) {
      throw new HttpError('errors.validation.failed', 400, [{ field: 'dispense_batch_ref' }]);
    }

    const mutation = await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
      const order = ensureScopedOrderRecord(
        await pharmacyWorkspaceRepository.txFindOrderById(
          tx,
          orderId,
          PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
        ),
        scope
      );

      assertTransition(['ORDERED', 'PARTIALLY_DISPENSED'].includes(order.status), {
        from: order.status,
        to: 'ATTEST_DISPENSE',
      });

      const prepareAttestation = await pharmacyWorkspaceRepository.txFindDispenseAttestation(
        tx,
        order.id,
        batchRef,
        'PREPARE'
      );
      assertTransition(Boolean(prepareAttestation), {
        reason: 'prepare_required',
        dispense_batch_ref: batchRef,
      });

      const existingAttest = await pharmacyWorkspaceRepository.txFindDispenseAttestation(
        tx,
        order.id,
        batchRef,
        'ATTEST'
      );
      if (existingAttest) {
        const refreshedOrder = await pharmacyWorkspaceRepository.txFindOrderById(
          tx,
          order.id,
          PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
        );
        return {
          order: refreshedOrder,
          batchRef,
          stockRecords: [],
          attestation: existingAttest,
        };
      }

      if (String(prepareAttestation.attested_by_user_id || '') === String(userId || '')) {
        throw new HttpError('errors.pharmacy_workspace.attestation.same_user', 400);
      }

      const pendingLogs = await pharmacyWorkspaceRepository.txFindDispenseLogsByBatch(
        tx,
        order.id,
        batchRef,
        {
          pharmacy_order_item: {
            include: {
              drug: {
                include: {
                  inventory_maps: {
                    where: { deleted_at: null },
                    orderBy: [{ is_default: 'desc' }, { created_at: 'asc' }],
                    include: {
                      inventory_item: true,
                    },
                  },
                },
              },
            },
          },
        }
      );

      const pendingOnly = pendingLogs.filter(
        (entry) => String(entry.status || '').toUpperCase() === 'PENDING'
      );
      assertTransition(pendingOnly.length > 0, {
        reason: 'pending_logs_required',
        dispense_batch_ref: batchRef,
      });

      const resolvedFacilityId = await resolveScopedFacilityId(
        payload.facility_id || order.patient?.facility_id || null,
        scope,
        true
      );

      const attestedAt = toDateOrNull(payload.attested_at, new Date());
      const stockRecords = [];

      for (const log of pendingOnly) {
        const orderItem = log.pharmacy_order_item;
        if (!orderItem) {
          throw new HttpError('errors.pharmacy_order_item.not_found', 404);
        }

        const inventoryMap = await resolveInventoryMapForItem({
          tx,
          item: orderItem,
          tenantId: order.patient?.tenant_id || null,
          inventoryItemIdentifier: null,
        });

        if (!inventoryMap) {
          throw new HttpError('errors.pharmacy_workspace.inventory_map.required', 400, [
            { order_item_id: orderItem.id },
          ]);
        }

        const stockDelta = normalizeStockDeductionQuantity(
          log.quantity_dispensed,
          inventoryMap.deduction_factor
        );

        const stockRecord = await pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility(
          tx,
          inventoryMap.inventory_item_id,
          resolvedFacilityId,
          INVENTORY_STOCK_WITH_RELATIONS_INCLUDE
        );
        if (!stockRecord) {
          throw new HttpError('errors.pharmacy_workspace.stock.not_found', 404, [
            { inventory_item_id: inventoryMap.inventory_item_id },
          ]);
        }
        const stock = ensureScopedInventoryStockRecord(stockRecord, scope);

        assertTransition(Number(stock.quantity || 0) >= stockDelta, {
          reason: 'insufficient_stock',
          inventory_item_id: inventoryMap.inventory_item_id,
          available: Number(stock.quantity || 0),
          required: stockDelta,
        });

        const updatedStock = await pharmacyWorkspaceRepository.txUpdateInventoryStock(tx, stock.id, {
          quantity: Number(stock.quantity || 0) - stockDelta,
        });

        await pharmacyWorkspaceRepository.txCreateStockMovement(tx, {
          inventory_item_id: inventoryMap.inventory_item_id,
          facility_id: resolvedFacilityId,
          movement_type: 'OUTBOUND',
          reason: 'DISPENSE',
          quantity: stockDelta,
          occurred_at: attestedAt,
        });

        await pharmacyWorkspaceRepository.txUpdateDispenseLog(tx, log.id, {
          status: 'DISPENSED',
          dispensed_at: attestedAt,
        });

        stockRecords.push({
          ...stock,
          ...updatedStock,
        });
      }

      const attestRecord = await pharmacyWorkspaceRepository.txCreateDispenseAttestation(tx, {
        pharmacy_order_id: order.id,
        dispense_batch_ref: batchRef,
        phase: 'ATTEST',
        attested_by_user_id: userId,
        attested_role: userRole || null,
        statement: payload.statement || null,
        reason: payload.reason || null,
        ip_address: ipAddress || null,
        attested_at: attestedAt,
      });

      let refreshedOrder = await pharmacyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
      );

      const rolledUpStatus = rollupOrderStatus(refreshedOrder);
      if (refreshedOrder.status !== rolledUpStatus) {
        await pharmacyWorkspaceRepository.txUpdateOrder(tx, order.id, {
          status: rolledUpStatus,
        });
        refreshedOrder = await pharmacyWorkspaceRepository.txFindOrderById(
          tx,
          order.id,
          PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
        );
      }

      return {
        order: refreshedOrder,
        batchRef,
        stockRecords,
        attestation: attestRecord,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'ATTEST_DISPENSE',
      entity: 'pharmacy_order',
      entity_id: mutation.order?.id,
      diff: {
        metadata: {
          dispense_batch_ref: mutation.batchRef,
          attestation_id: mutation.attestation?.id || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapPharmacyOrderWorkflowRecord(mutation.order);

    publishPharmacyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'ATTEST_DISPENSE',
      resourceType: 'dispense_batch',
      resourceId: mutation.batchRef,
      batchRef: mutation.batchRef,
      stockRecords: mutation.stockRecords,
    }).catch(() => {});

    const stockSummaryWhere = await buildInventoryStockWhere({}, scope, { includeSearch: false });
    const stockSummary = summarizeStockMetrics(
      await pharmacyWorkspaceRepository.findInventoryStockMetrics(stockSummaryWhere)
    );
    const orderSummary = await buildWorkbenchSummary(
      await buildWorkbenchOrderWhere({}, scope, { includeSearch: false })
    );

    return {
      workflow,
      dispense_batch_ref: mutation.batchRef,
      order_summary: orderSummary,
      stocks: mutation.stockRecords.map((record) => mapInventoryStockRecord(record)).filter(Boolean),
      stock_summary: stockSummary,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const cancelPharmacyOrder = async (identifier, payload = {}, userId, _userRole, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const orderId = await resolveScopedOrderId(identifier, scope);

    const mutation = await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
      const order = ensureScopedOrderRecord(
        await pharmacyWorkspaceRepository.txFindOrderById(
          tx,
          orderId,
          PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
        ),
        scope
      );

      assertTransition(['ORDERED', 'PARTIALLY_DISPENSED'].includes(order.status), {
        from: order.status,
        to: 'CANCELLED',
      });

      await pharmacyWorkspaceRepository.txUpdateManyDispenseLogs(
        tx,
        {
          status: 'PENDING',
          pharmacy_order_item: {
            pharmacy_order_id: order.id,
          },
        },
        {
          status: 'CANCELLED',
        }
      );

      await pharmacyWorkspaceRepository.txUpdateOrder(tx, order.id, {
        status: 'CANCELLED',
      });

      const refreshedOrder = await pharmacyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return { order: refreshedOrder };
    });

    createAuditLog({
      user_id: userId,
      action: 'CANCEL',
      entity: 'pharmacy_order',
      entity_id: mutation.order?.id,
      diff: {
        metadata: {
          reason: payload.reason || null,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapPharmacyOrderWorkflowRecord(mutation.order);

    publishPharmacyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'CANCEL_ORDER',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
    }).catch(() => {});

    const orderSummary = await buildWorkbenchSummary(
      await buildWorkbenchOrderWhere({}, scope, { includeSearch: false })
    );

    return {
      workflow,
      order_summary: orderSummary,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const returnDispense = async (identifier, payload = {}, userId, userRole, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const orderId = await resolveScopedOrderId(identifier, scope);

    const mutation = await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
      const order = ensureScopedOrderRecord(
        await pharmacyWorkspaceRepository.txFindOrderById(
          tx,
          orderId,
          PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
        ),
        scope
      );

      assertTransition(['DISPENSED', 'PARTIALLY_DISPENSED'].includes(order.status), {
        from: order.status,
        to: 'RETURN',
      });

      const resolvedFacilityId = await resolveScopedFacilityId(
        payload.facility_id || order.patient?.facility_id || null,
        scope,
        true
      );

      const stockRecords = [];
      const returnedAt = new Date();

      for (const line of payload.items || []) {
        const orderItem = resolveOrderItemByIdentifier(order, line.order_item_id);
        if (!orderItem) {
          throw new HttpError('errors.pharmacy_order_item.not_found', 404);
        }

        const quantity = Number(line.quantity || 0);
        assertTransition(Number.isFinite(quantity) && quantity > 0, {
          reason: 'invalid_return_quantity',
          order_item_id: line.order_item_id,
        });

        const metrics = computeItemDispensedMetrics(orderItem);
        assertTransition(quantity <= metrics.netDispensed, {
          reason: 'return_exceeds_dispensed',
          order_item_id: line.order_item_id,
          dispensed: metrics.netDispensed,
          requested: quantity,
        });

        const inventoryMap = await resolveInventoryMapForItem({
          tx,
          item: orderItem,
          tenantId: order.patient?.tenant_id || null,
          inventoryItemIdentifier: line.inventory_item_id || null,
        });
        if (!inventoryMap) {
          throw new HttpError('errors.pharmacy_workspace.inventory_map.required', 400, [
            { order_item_id: orderItem.id },
          ]);
        }

        const stockDelta = normalizeStockDeductionQuantity(quantity, inventoryMap.deduction_factor);

        let stock = await pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility(
          tx,
          inventoryMap.inventory_item_id,
          resolvedFacilityId,
          INVENTORY_STOCK_WITH_RELATIONS_INCLUDE
        );

        if (!stock) {
          stock = await pharmacyWorkspaceRepository.txCreateInventoryStock(tx, {
            inventory_item_id: inventoryMap.inventory_item_id,
            facility_id: resolvedFacilityId,
            quantity: 0,
            reorder_level: 0,
          });
        } else {
          ensureScopedInventoryStockRecord(stock, scope);
        }

        const updatedStock = await pharmacyWorkspaceRepository.txUpdateInventoryStock(tx, stock.id, {
          quantity: Number(stock.quantity || 0) + stockDelta,
        });

        await pharmacyWorkspaceRepository.txCreateStockMovement(tx, {
          inventory_item_id: inventoryMap.inventory_item_id,
          facility_id: resolvedFacilityId,
          movement_type: 'INBOUND',
          reason: 'RETURN',
          quantity: stockDelta,
          occurred_at: returnedAt,
        });

        await pharmacyWorkspaceRepository.txCreateDispenseLog(tx, {
          pharmacy_order_item_id: orderItem.id,
          dispense_batch_ref: null,
          status: 'RETURNED',
          quantity_dispensed: quantity,
          dispensed_at: returnedAt,
        });

        stockRecords.push({
          ...stock,
          ...updatedStock,
        });
      }

      let refreshedOrder = await pharmacyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
      );

      const rolledUpStatus = rollupOrderStatus(refreshedOrder);
      if (refreshedOrder.status !== rolledUpStatus) {
        await pharmacyWorkspaceRepository.txUpdateOrder(tx, order.id, {
          status: rolledUpStatus,
        });
        refreshedOrder = await pharmacyWorkspaceRepository.txFindOrderById(
          tx,
          order.id,
          PHARMACY_ORDER_WITH_RELATIONS_INCLUDE
        );
      }

      await pharmacyWorkspaceRepository.txCreateDispenseAttestation(tx, {
        pharmacy_order_id: order.id,
        dispense_batch_ref: `RETURN-${buildDispenseBatchRef()}`,
        phase: 'PREPARE',
        attested_by_user_id: userId,
        attested_role: userRole || null,
        statement: payload.notes || null,
        reason: payload.reason || 'RETURN',
        ip_address: ipAddress || null,
        attested_at: returnedAt,
      });

      return {
        order: refreshedOrder,
        stockRecords,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'RETURN_DISPENSE',
      entity: 'pharmacy_order',
      entity_id: mutation.order?.id,
      diff: {
        metadata: {
          item_count: Array.isArray(payload.items) ? payload.items.length : 0,
          reason: payload.reason || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapPharmacyOrderWorkflowRecord(mutation.order);

    publishPharmacyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'RETURN_DISPENSE',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
      stockRecords: mutation.stockRecords,
    }).catch(() => {});

    const stockSummaryWhere = await buildInventoryStockWhere({}, scope, { includeSearch: false });
    const stockSummary = summarizeStockMetrics(
      await pharmacyWorkspaceRepository.findInventoryStockMetrics(stockSummaryWhere)
    );
    const orderSummary = await buildWorkbenchSummary(
      await buildWorkbenchOrderWhere({}, scope, { includeSearch: false })
    );

    return {
      workflow,
      order_summary: orderSummary,
      stocks: mutation.stockRecords.map((record) => mapInventoryStockRecord(record)).filter(Boolean),
      stock_summary: stockSummary,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getInventoryStock = async (filters, page, limit, sortBy, order, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { updated_at: 'desc' };

    const [where, summaryWhere] = await Promise.all([
      buildInventoryStockWhere(filters, scope, { includeSearch: true }),
      buildInventoryStockWhere(filters, scope, { includeSearch: false }),
    ]);

    const [records, total, stockMetrics] = await Promise.all([
      pharmacyWorkspaceRepository.findManyInventoryStocks(
        where,
        skip,
        limit,
        orderBy,
        INVENTORY_STOCK_WITH_RELATIONS_INCLUDE
      ),
      pharmacyWorkspaceRepository.countInventoryStocks(where),
      pharmacyWorkspaceRepository.findInventoryStockMetrics(summaryWhere),
    ]);
    const stockSummary = summarizeStockMetrics(stockMetrics);

    return {
      summary: stockSummary,
      stocks: records.map((record) => mapInventoryStockRecord(record)).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const adjustInventoryStock = async (payload = {}, userId, _userRole, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const inventoryItemId = await resolveScopedInventoryItemId(payload.inventory_item_id, scope);
    const facilityId = await resolveScopedFacilityId(payload.facility_id || null, scope, true);

    const mutation = await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
      let stock = await pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility(
        tx,
        inventoryItemId,
        facilityId,
        INVENTORY_STOCK_WITH_RELATIONS_INCLUDE
      );

      if (!stock) {
        stock = await pharmacyWorkspaceRepository.txCreateInventoryStock(tx, {
          inventory_item_id: inventoryItemId,
          facility_id: facilityId,
          quantity: 0,
          reorder_level: 0,
        });
      } else {
        ensureScopedInventoryStockRecord(stock, scope);
      }

      const quantityDelta = Number(payload.quantity_delta || 0);
      const nextQuantity = Number(stock.quantity || 0) + quantityDelta;

      assertTransition(nextQuantity >= 0, {
        reason: 'negative_stock_after_adjustment',
        current: Number(stock.quantity || 0),
        delta: quantityDelta,
      });

      const updatedStock = await pharmacyWorkspaceRepository.txUpdateInventoryStock(tx, stock.id, {
        quantity: nextQuantity,
      });

      const movement = await pharmacyWorkspaceRepository.txCreateStockMovement(tx, {
        inventory_item_id: inventoryItemId,
        facility_id: facilityId,
        movement_type: 'ADJUSTMENT',
        reason: payload.reason || 'OTHER',
        quantity: Math.abs(quantityDelta),
        occurred_at: toDateOrNull(payload.occurred_at, new Date()),
      });

      const refreshedStock = await pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility(
        tx,
        inventoryItemId,
        facilityId,
        INVENTORY_STOCK_WITH_RELATIONS_INCLUDE
      );

      return {
        stock: refreshedStock
          ? ensureScopedInventoryStockRecord(refreshedStock, scope)
          : { ...stock, ...updatedStock },
        movement,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'ADJUST_STOCK',
      entity: 'inventory_stock',
      entity_id: mutation.stock?.id || null,
      diff: {
        metadata: {
          inventory_item_id: inventoryItemId,
          quantity_delta: Number(payload.quantity_delta || 0),
          reason: payload.reason || null,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const stockSummaryWhere = await buildInventoryStockWhere({}, scope, { includeSearch: false });
    const stockSummary = summarizeStockMetrics(
      await pharmacyWorkspaceRepository.findInventoryStockMetrics(stockSummaryWhere)
    );

    return {
      stock: mapInventoryStockRecord(mutation.stock),
      stock_summary: stockSummary,
      movement: {
        id: toPublicIdentifier(mutation.movement?.human_friendly_id, mutation.movement?.id),
        movement_type: mutation.movement?.movement_type || null,
        reason: mutation.movement?.reason || null,
        quantity: Number(mutation.movement?.quantity || 0),
        occurred_at: mutation.movement?.occurred_at
          ? new Date(mutation.movement.occurred_at).toISOString()
          : null,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const resolveLegacyRouteIdentifier = async (resource, identifier, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const normalizedResource = String(resource || '').trim().toLowerCase();
    const normalizedIdentifier = normalizeIdentifier(identifier);
    if (!normalizedIdentifier) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    const config = LEGACY_ROUTE_CONFIG[normalizedResource];
    if (!config) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    const record = await resolveModelRecordOrThrow({
      identifier: normalizedIdentifier,
      model: config.model,
      where: {
        deleted_at: null,
        ...buildLegacyScopeWhere(config.model, scope),
      },
      select: {
        id: true,
        human_friendly_id: true,
      },
      errorKey: 'errors.resource.not_found',
    });

    const publicIdentifier = toPublicIdentifier(record?.human_friendly_id, normalizedIdentifier);
    const safeIdentifier =
      publicIdentifier ||
      (isUuidLike(normalizedIdentifier) ? null : String(normalizedIdentifier).trim().toUpperCase());

    if (!safeIdentifier) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    const routePrefix = config.route || '/pharmacy';
    const hasQuerySuffix = routePrefix.endsWith('=');
    const route = hasQuerySuffix
      ? `${routePrefix}${encodeURIComponent(safeIdentifier)}`
      : `${routePrefix}/${encodeURIComponent(safeIdentifier)}`;

    return {
      id: safeIdentifier,
      resource: config.resource,
      identifier: safeIdentifier,
      route,
      matched_by: isUuidLike(normalizedIdentifier) ? 'uuid' : 'human_friendly_id',
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  getPharmacyWorkbench,
  getPharmacyOrderWorkflow,
  searchDrugs,
  createPharmacyOrder,
  prepareDispense,
  attestDispense,
  cancelPharmacyOrder,
  returnDispense,
  getInventoryStock,
  adjustInventoryStock,
  resolveLegacyRouteIdentifier,
};
