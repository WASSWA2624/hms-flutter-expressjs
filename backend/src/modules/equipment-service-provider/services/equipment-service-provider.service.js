const equipmentServiceProviderRepository = require('@repositories/equipment-service-provider/equipment-service-provider.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const listEquipmentServiceProviders = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
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
    equipmentServiceProviderRepository.findMany(where, skip, limit, orderBy),
    equipmentServiceProviderRepository.count(where)
  ]);

  return {
    equipmentServiceProviders: items,
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

const getEquipmentServiceProviderById = async (id) => {
  const item = await equipmentServiceProviderRepository.findById(id);
  if (!item) throw new HttpError('errors.equipment_service_provider.not_found', 404);
  return item;
};

const createEquipmentServiceProvider = async (data, context = {}) => {
  const item = await equipmentServiceProviderRepository.create(data);
  const tenantId = item.tenant_id || data.tenant_id || context.tenant_id;
  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id || context.user?.id,
    action: 'CREATE',
    entity: 'equipment_service_provider',
    entity_id: item.id,
    diff: { after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const updateEquipmentServiceProvider = async (id, data, context = {}) => {
  const before = await equipmentServiceProviderRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_service_provider.not_found', 404);
  const item = await equipmentServiceProviderRepository.update(id, data);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_service_provider',
    entity_id: item.id,
    diff: { before, after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const deleteEquipmentServiceProvider = async (id, context = {}) => {
  const before = await equipmentServiceProviderRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_service_provider.not_found', 404);
  await equipmentServiceProviderRepository.softDelete(id);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'DELETE',
    entity: 'equipment_service_provider',
    entity_id: id,
    diff: { before },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
};

module.exports = { listEquipmentServiceProviders, getEquipmentServiceProviderById, createEquipmentServiceProvider, updateEquipmentServiceProvider, deleteEquipmentServiceProvider };
