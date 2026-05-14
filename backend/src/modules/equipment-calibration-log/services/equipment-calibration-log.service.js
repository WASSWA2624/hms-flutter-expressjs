const equipmentCalibrationLogRepository = require('@repositories/equipment-calibration-log/equipment-calibration-log.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const listEquipmentCalibrationLogs = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
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
    equipmentCalibrationLogRepository.findMany(where, skip, limit, orderBy),
    equipmentCalibrationLogRepository.count(where)
  ]);

  return {
    equipmentCalibrationLogs: items,
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

const getEquipmentCalibrationLogById = async (id) => {
  const item = await equipmentCalibrationLogRepository.findById(id);
  if (!item) throw new HttpError('errors.equipment_calibration_log.not_found', 404);
  return item;
};

const createEquipmentCalibrationLog = async (data, context = {}) => {
  const item = await equipmentCalibrationLogRepository.create(data);
  const tenantId = item.tenant_id || data.tenant_id || context.tenant_id;
  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id || context.user?.id,
    action: 'CREATE',
    entity: 'equipment_calibration_log',
    entity_id: item.id,
    diff: { after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const updateEquipmentCalibrationLog = async (id, data, context = {}) => {
  const before = await equipmentCalibrationLogRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_calibration_log.not_found', 404);
  const item = await equipmentCalibrationLogRepository.update(id, data);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_calibration_log',
    entity_id: item.id,
    diff: { before, after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const deleteEquipmentCalibrationLog = async (id, context = {}) => {
  const before = await equipmentCalibrationLogRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_calibration_log.not_found', 404);
  await equipmentCalibrationLogRepository.softDelete(id);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'DELETE',
    entity: 'equipment_calibration_log',
    entity_id: id,
    diff: { before },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
};

module.exports = { listEquipmentCalibrationLogs, getEquipmentCalibrationLogById, createEquipmentCalibrationLog, updateEquipmentCalibrationLog, deleteEquipmentCalibrationLog };
