const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const ACTIVE_STORAGE_WHERE = {
  deleted_at: null,
  is_active: true};

const findManyStorageRooms = async (where = {}, skip = 0, limit = 100, orderBy = { name: 'asc' }) =>
  withDbErrorHandling(() =>
    prisma.pharmacy_storage_room.findMany({
      where: { deleted_at: null, ...where },
      skip,
      take: limit,
      orderBy,
      include: {
        shelves: {
          where: { deleted_at: null },
          orderBy: [{ is_active: 'desc' }, { shelf_code: 'asc' }]}}})
  );

const countStorageRooms = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.pharmacy_storage_room.count({
      where: { deleted_at: null, ...where }})
  );

const findStorageRoomById = async (id, includeInactive = false) =>
  withDbErrorHandling(() =>
    prisma.pharmacy_storage_room.findFirst({
      where: {
        deleted_at: null,
        ...(includeInactive ? {} : { is_active: true }),
        OR: [{ id }, { human_friendly_id: id }]},
      include: {
        shelves: {
          where: { deleted_at: null },
          orderBy: [{ is_active: 'desc' }, { shelf_code: 'asc' }]}}})
  );

const findStorageShelfById = async (id, includeInactive = false) =>
  withDbErrorHandling(() =>
    prisma.pharmacy_storage_shelf.findFirst({
      where: {
        deleted_at: null,
        ...(includeInactive ? {} : { is_active: true }),
        OR: [{ id }, { human_friendly_id: id }]},
      include: {
        storage_room: true}})
  );

const txCreateStorageRoom = async (tx, data) => tx.pharmacy_storage_room.create({ data });

const txUpdateStorageRoom = async (tx, id, data) =>
  tx.pharmacy_storage_room.update({
    where: { id },
    data});

const txCreateStorageShelf = async (tx, data) => tx.pharmacy_storage_shelf.create({ data });

const txUpdateStorageShelf = async (tx, id, data) =>
  tx.pharmacy_storage_shelf.update({
    where: { id },
    data});

const txSoftDeleteStorageRoom = async (tx, id, deletedAt = new Date()) =>
  tx.pharmacy_storage_room.update({
    where: { id },
    data: { deleted_at: deletedAt, is_active: false }});

const txSoftDeleteShelvesForRoom = async (tx, storageRoomId, deletedAt = new Date()) =>
  tx.pharmacy_storage_shelf.updateMany({
    where: { storage_room_id: storageRoomId, deleted_at: null },
    data: { deleted_at: deletedAt, is_active: false }});

const txSoftDeleteStorageShelf = async (tx, id, deletedAt = new Date()) =>
  tx.pharmacy_storage_shelf.update({
    where: { id },
    data: { deleted_at: deletedAt, is_active: false }});

const findDrugBatchesWithStorageByDrugIds = async (drugIds = []) =>
  withDbErrorHandling(() => {
    const normalized = Array.from(new Set((drugIds || []).filter(Boolean)));
    if (!normalized.length) return [];
    return prisma.drug_batch.findMany({
      where: {
        deleted_at: null,
        drug_id: { in: normalized }},
      select: {
        id: true,
        drug_id: true,
        batch_number: true,
        expiry_date: true,
        quantity: true,
        storage_room_id: true,
        storage_shelf_id: true,
        storage_room: {
          select: {
            id: true,
            human_friendly_id: true,
            name: true,
            code: true,
            is_active: true}},
        storage_shelf: {
          select: {
            id: true,
            human_friendly_id: true,
            shelf_code: true,
            label: true,
            is_active: true,
            storage_room_id: true}}},
      orderBy: [{ quantity: 'desc' }, { expiry_date: 'asc' }, { created_at: 'desc' }]});
  });

const findInventoryItemIdsByStorageFilters = async (tenantId, filters = {}) =>
  withDbErrorHandling(async () => {
    const batchWhere = { deleted_at: null };
    if (filters.storage_room_id) {
      batchWhere.storage_room_id = filters.storage_room_id;
    }
    if (filters.storage_shelf_id) {
      batchWhere.storage_shelf_id = filters.storage_shelf_id;
    }
    if (!batchWhere.storage_room_id && !batchWhere.storage_shelf_id) {
      return null;
    }

    const batches = await prisma.drug_batch.findMany({
      where: batchWhere,
      select: { drug_id: true }});
    const drugIds = Array.from(new Set(batches.map((row) => row.drug_id).filter(Boolean)));
    if (!drugIds.length) return [];

    const maps = await prisma.drug_inventory_map.findMany({
      where: {
        deleted_at: null,
        tenant_id: tenantId,
        drug_id: { in: drugIds }},
      select: { inventory_item_id: true }});
    return Array.from(new Set(maps.map((row) => row.inventory_item_id).filter(Boolean)));
  });

const findDrugIdsByStorageFilters = async (tenantId, filters = {}) =>
  withDbErrorHandling(async () => {
    const batchWhere = { deleted_at: null };
    if (filters.storage_room_id) {
      batchWhere.storage_room_id = filters.storage_room_id;
    }
    if (filters.storage_shelf_id) {
      batchWhere.storage_shelf_id = filters.storage_shelf_id;
    }
    if (!batchWhere.storage_room_id && !batchWhere.storage_shelf_id) {
      return null;
    }

    const batches = await prisma.drug_batch.findMany({
      where: batchWhere,
      select: { drug_id: true }});
    return Array.from(new Set(batches.map((row) => row.drug_id).filter(Boolean)));
  });

module.exports = {
  ACTIVE_STORAGE_WHERE,
  findManyStorageRooms,
  countStorageRooms,
  findStorageRoomById,
  findStorageShelfById,
  txCreateStorageRoom,
  txUpdateStorageRoom,
  txCreateStorageShelf,
  txUpdateStorageShelf,
  txSoftDeleteStorageRoom,
  txSoftDeleteShelvesForRoom,
  txSoftDeleteStorageShelf,
  findDrugBatchesWithStorageByDrugIds,
  findInventoryItemIdsByStorageFilters,
  findDrugIdsByStorageFilters};
