const equipmentSafetyTestLogRepository = require('@repositories/equipment-safety-test-log/equipment-safety-test-log.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const listEquipmentSafetyTestLogs = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
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
    equipmentSafetyTestLogRepository.findMany(where, skip, limit, orderBy),
    equipmentSafetyTestLogRepository.count(where)
  ]);

  return {
    equipmentSafetyTestLogs: items,
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

const getEquipmentSafetyTestLogById = async (id) => {
  const item = await equipmentSafetyTestLogRepository.findById(id);
  if (!item) throw new HttpError('errors.equipment_safety_test_log.not_found', 404);
  return item;
};

const createEquipmentSafetyTestLog = async (data, context = {}) => {
  const item = await equipmentSafetyTestLogRepository.create(data);
  const tenantId = item.tenant_id || data.tenant_id || context.tenant_id;
  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id || context.user?.id,
    action: 'CREATE',
    entity: 'equipment_safety_test_log',
    entity_id: item.id,
    diff: { after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const updateEquipmentSafetyTestLog = async (id, data, context = {}) => {
  const before = await equipmentSafetyTestLogRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_safety_test_log.not_found', 404);
  const item = await equipmentSafetyTestLogRepository.update(id, data);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_safety_test_log',
    entity_id: item.id,
    diff: { before, after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const deleteEquipmentSafetyTestLog = async (id, context = {}) => {
  const before = await equipmentSafetyTestLogRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_safety_test_log.not_found', 404);
  await equipmentSafetyTestLogRepository.softDelete(id);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'DELETE',
    entity: 'equipment_safety_test_log',
    entity_id: id,
    diff: { before },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
};

module.exports = { listEquipmentSafetyTestLogs, getEquipmentSafetyTestLogById, createEquipmentSafetyTestLog, updateEquipmentSafetyTestLog, deleteEquipmentSafetyTestLog };
