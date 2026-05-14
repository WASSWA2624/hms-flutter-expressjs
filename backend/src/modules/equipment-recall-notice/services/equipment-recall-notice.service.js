const equipmentRecallNoticeRepository = require('@repositories/equipment-recall-notice/equipment-recall-notice.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const listEquipmentRecallNotices = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
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
    equipmentRecallNoticeRepository.findMany(where, skip, limit, orderBy),
    equipmentRecallNoticeRepository.count(where)
  ]);

  return {
    equipmentRecallNotices: items,
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

const getEquipmentRecallNoticeById = async (id) => {
  const item = await equipmentRecallNoticeRepository.findById(id);
  if (!item) throw new HttpError('errors.equipment_recall_notice.not_found', 404);
  return item;
};

const createEquipmentRecallNotice = async (data, context = {}) => {
  const item = await equipmentRecallNoticeRepository.create(data);
  const tenantId = item.tenant_id || data.tenant_id || context.tenant_id;
  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id || context.user?.id,
    action: 'CREATE',
    entity: 'equipment_recall_notice',
    entity_id: item.id,
    diff: { after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const updateEquipmentRecallNotice = async (id, data, context = {}) => {
  const before = await equipmentRecallNoticeRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_recall_notice.not_found', 404);
  const item = await equipmentRecallNoticeRepository.update(id, data);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_recall_notice',
    entity_id: item.id,
    diff: { before, after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const deleteEquipmentRecallNotice = async (id, context = {}) => {
  const before = await equipmentRecallNoticeRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_recall_notice.not_found', 404);
  await equipmentRecallNoticeRepository.softDelete(id);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'DELETE',
    entity: 'equipment_recall_notice',
    entity_id: id,
    diff: { before },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
};

module.exports = { listEquipmentRecallNotices, getEquipmentRecallNoticeById, createEquipmentRecallNotice, updateEquipmentRecallNotice, deleteEquipmentRecallNotice };
