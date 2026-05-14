const equipmentLocationHistoryRepository = require('@repositories/equipment-location-history/equipment-location-history.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const listEquipmentLocationHistorys = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
  const where = {};
  if (filters.tenant_id) where.tenant_id = filters.tenant_id;
  if (filters.search) {
    where.OR = [
      { name: { contains: filters.search, mode: 'insensitive' } },
      { description: { contains: filters.search, mode: 'insensitive' } }
    ];
  }

  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };
  const [items, total] = await Promise.all([
    equipmentLocationHistoryRepository.findMany(where, skip, limit, orderBy),
    equipmentLocationHistoryRepository.count(where)
  ]);

  return {
    equipmentLocationHistories: items,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
      hasNextPage: page < Math.ceil(total / limit),
      hasPreviousPage: page > 1
    }
  };
};

const getEquipmentLocationHistoryById = async (id) => {
  const item = await equipmentLocationHistoryRepository.findById(id);
  if (!item) throw new HttpError('errors.equipment_location_history.not_found', 404);
  return item;
};

const createEquipmentLocationHistory = async (data, context = {}) => {
  const item = await equipmentLocationHistoryRepository.create(data);
  const tenantId = item.tenant_id || data.tenant_id || context.tenant_id;
  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id || context.user?.id,
    action: 'CREATE',
    entity: 'equipment_location_history',
    entity_id: item.id,
    diff: { after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const updateEquipmentLocationHistory = async (id, data, context = {}) => {
  const before = await equipmentLocationHistoryRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_location_history.not_found', 404);
  const item = await equipmentLocationHistoryRepository.update(id, data);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_location_history',
    entity_id: item.id,
    diff: { before, after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const deleteEquipmentLocationHistory = async (id, context = {}) => {
  const before = await equipmentLocationHistoryRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_location_history.not_found', 404);
  await equipmentLocationHistoryRepository.softDelete(id);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'DELETE',
    entity: 'equipment_location_history',
    entity_id: id,
    diff: { before },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
};

module.exports = { listEquipmentLocationHistorys, getEquipmentLocationHistoryById, createEquipmentLocationHistory, updateEquipmentLocationHistory, deleteEquipmentLocationHistory };
