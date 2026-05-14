const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error?.code === 'P2025') {
      throw new HttpError('errors.resource.not_found', 404);
    }
    if (error?.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error?.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findManyOrders = async (where, skip, take, orderBy, include) =>
  withDbErrorHandling(() =>
    prisma.pharmacy_order.findMany({
      where: { deleted_at: null, ...(where || {}) },
      skip,
      take,
      orderBy,
      include,
    })
  );

const countOrders = async (where) =>
  withDbErrorHandling(() =>
    prisma.pharmacy_order.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const findOrderById = async (id, include) =>
  withDbErrorHandling(() =>
    prisma.pharmacy_order.findFirst({
      where: { id, deleted_at: null },
      include,
    })
  );

const countDispenseAttestations = async (where) =>
  withDbErrorHandling(() =>
    prisma.pharmacy_dispense_attestation.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const findManyInventoryStocks = async (where, skip, take, orderBy, include) =>
  withDbErrorHandling(() =>
    prisma.inventory_stock.findMany({
      where: { deleted_at: null, ...(where || {}) },
      skip,
      take,
      orderBy,
      include,
    })
  );

const countInventoryStocks = async (where) =>
  withDbErrorHandling(() =>
    prisma.inventory_stock.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const findInventoryStockMetrics = async (where) =>
  withDbErrorHandling(() =>
    prisma.inventory_stock.findMany({
      where: { deleted_at: null, ...(where || {}) },
      select: {
        quantity: true,
        reorder_level: true,
      },
    })
  );

const findManyDrugs = async (where, skip, take, orderBy, include) =>
  withDbErrorHandling(() =>
    prisma.drug.findMany({
      where: { deleted_at: null, ...(where || {}) },
      skip,
      take,
      orderBy,
      include,
    })
  );

const countDrugs = async (where) =>
  withDbErrorHandling(() =>
    prisma.drug.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const withTransaction = async (callback) =>
  withDbErrorHandling(() => prisma.$transaction((tx) => callback(tx)));

const txFindOrderById = async (tx, id, include) =>
  tx.pharmacy_order.findFirst({
    where: { id, deleted_at: null },
    include,
  });

const txUpdateOrder = async (tx, id, data) =>
  tx.pharmacy_order.update({
    where: { id },
    data,
  });

const txFindStockByInventoryItemAndFacility = async (tx, inventoryItemId, facilityId = null, include) =>
  tx.inventory_stock.findFirst({
    where: {
      deleted_at: null,
      inventory_item_id: inventoryItemId,
      facility_id: facilityId,
    },
    include,
  });

const txCreateInventoryStock = async (tx, data) =>
  tx.inventory_stock.create({
    data,
  });

const txUpdateInventoryStock = async (tx, id, data) =>
  tx.inventory_stock.update({
    where: { id },
    data,
  });

const txCreateStockMovement = async (tx, data) =>
  tx.stock_movement.create({
    data,
  });

const txCreateDispenseLog = async (tx, data) =>
  tx.dispense_log.create({
    data,
  });

const txUpdateDispenseLog = async (tx, id, data) =>
  tx.dispense_log.update({
    where: { id },
    data,
  });

const txUpdateManyDispenseLogs = async (tx, where, data) =>
  tx.dispense_log.updateMany({
    where: { deleted_at: null, ...(where || {}) },
    data,
  });

const txFindDispenseLogsByBatch = async (tx, pharmacyOrderId, batchRef, include = undefined) =>
  tx.dispense_log.findMany({
    where: {
      deleted_at: null,
      dispense_batch_ref: batchRef,
      pharmacy_order_item: {
        deleted_at: null,
        pharmacy_order_id: pharmacyOrderId,
      },
    },
    orderBy: { created_at: 'asc' },
    include,
  });

const txCreateDispenseAttestation = async (tx, data) =>
  tx.pharmacy_dispense_attestation.create({
    data,
  });

const txFindDispenseAttestation = async (tx, pharmacyOrderId, batchRef, phase) =>
  tx.pharmacy_dispense_attestation.findFirst({
    where: {
      deleted_at: null,
      pharmacy_order_id: pharmacyOrderId,
      dispense_batch_ref: batchRef,
      phase,
    },
    orderBy: { created_at: 'desc' },
  });

const txFindManyDispenseAttestations = async (tx, where, orderBy = { created_at: 'desc' }) =>
  tx.pharmacy_dispense_attestation.findMany({
    where: { deleted_at: null, ...(where || {}) },
    orderBy,
  });

const txFindInventoryMapByDrug = async (tx, drugId, tenantId = null) =>
  tx.drug_inventory_map.findFirst({
    where: {
      deleted_at: null,
      drug_id: drugId,
      ...(tenantId ? { tenant_id: tenantId } : {}),
    },
    orderBy: [{ is_default: 'desc' }, { created_at: 'asc' }],
    include: {
      inventory_item: true,
    },
  });

const txFindInventoryMapByDrugAndItem = async (tx, drugId, inventoryItemId, tenantId = null) =>
  tx.drug_inventory_map.findFirst({
    where: {
      deleted_at: null,
      drug_id: drugId,
      inventory_item_id: inventoryItemId,
      ...(tenantId ? { tenant_id: tenantId } : {}),
    },
    include: {
      inventory_item: true,
    },
  });

module.exports = {
  findManyOrders,
  countOrders,
  findOrderById,
  countDispenseAttestations,
  findManyInventoryStocks,
  countInventoryStocks,
  findInventoryStockMetrics,
  findManyDrugs,
  countDrugs,
  withTransaction,
  txFindOrderById,
  txUpdateOrder,
  txFindStockByInventoryItemAndFacility,
  txCreateInventoryStock,
  txUpdateInventoryStock,
  txCreateStockMovement,
  txCreateDispenseLog,
  txUpdateDispenseLog,
  txUpdateManyDispenseLogs,
  txFindDispenseLogsByBatch,
  txCreateDispenseAttestation,
  txFindDispenseAttestation,
  txFindManyDispenseAttestations,
  txFindInventoryMapByDrug,
  txFindInventoryMapByDrugAndItem,
};
