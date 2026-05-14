const equipmentDisposalTransferRepository = require('@repositories/equipment-disposal-transfer/equipment-disposal-transfer.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const listEquipmentDisposalTransfers = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
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
    equipmentDisposalTransferRepository.findMany(where, skip, limit, orderBy),
    equipmentDisposalTransferRepository.count(where)
  ]);

  return {
    equipmentDisposalTransfers: items,
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

const getEquipmentDisposalTransferById = async (id) => {
  const item = await equipmentDisposalTransferRepository.findById(id);
  if (!item) throw new HttpError('errors.equipment_disposal_transfer.not_found', 404);
  return item;
};

const createEquipmentDisposalTransfer = async (data, context = {}) => {
  const item = await equipmentDisposalTransferRepository.create(data);
  const tenantId = item.tenant_id || data.tenant_id || context.tenant_id;
  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id || context.user?.id,
    action: 'CREATE',
    entity: 'equipment_disposal_transfer',
    entity_id: item.id,
    diff: { after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const updateEquipmentDisposalTransfer = async (id, data, context = {}) => {
  const before = await equipmentDisposalTransferRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_disposal_transfer.not_found', 404);
  const item = await equipmentDisposalTransferRepository.update(id, data);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_disposal_transfer',
    entity_id: item.id,
    diff: { before, after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const deleteEquipmentDisposalTransfer = async (id, context = {}) => {
  const before = await equipmentDisposalTransferRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_disposal_transfer.not_found', 404);
  await equipmentDisposalTransferRepository.softDelete(id);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'DELETE',
    entity: 'equipment_disposal_transfer',
    entity_id: id,
    diff: { before },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
};

module.exports = { listEquipmentDisposalTransfers, getEquipmentDisposalTransferById, createEquipmentDisposalTransfer, updateEquipmentDisposalTransfer, deleteEquipmentDisposalTransfer };
