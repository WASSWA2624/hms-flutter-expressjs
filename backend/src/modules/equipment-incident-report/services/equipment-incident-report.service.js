const equipmentIncidentReportRepository = require('@repositories/equipment-incident-report/equipment-incident-report.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const listEquipmentIncidentReports = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
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
    equipmentIncidentReportRepository.findMany(where, skip, limit, orderBy),
    equipmentIncidentReportRepository.count(where)
  ]);

  return {
    equipmentIncidentReports: items,
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

const getEquipmentIncidentReportById = async (id) => {
  const item = await equipmentIncidentReportRepository.findById(id);
  if (!item) throw new HttpError('errors.equipment_incident_report.not_found', 404);
  return item;
};

const createEquipmentIncidentReport = async (data, context = {}) => {
  const item = await equipmentIncidentReportRepository.create(data);
  const tenantId = item.tenant_id || data.tenant_id || context.tenant_id;
  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id || context.user?.id,
    action: 'CREATE',
    entity: 'equipment_incident_report',
    entity_id: item.id,
    diff: { after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const updateEquipmentIncidentReport = async (id, data, context = {}) => {
  const before = await equipmentIncidentReportRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_incident_report.not_found', 404);
  const item = await equipmentIncidentReportRepository.update(id, data);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'UPDATE',
    entity: 'equipment_incident_report',
    entity_id: item.id,
    diff: { before, after: item },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
  return item;
};

const deleteEquipmentIncidentReport = async (id, context = {}) => {
  const before = await equipmentIncidentReportRepository.findById(id);
  if (!before) throw new HttpError('errors.equipment_incident_report.not_found', 404);
  await equipmentIncidentReportRepository.softDelete(id);
  createAuditLog({
    tenant_id: before.tenant_id || context.tenant_id,
    user_id: context.user_id || context.user?.id,
    action: 'DELETE',
    entity: 'equipment_incident_report',
    entity_id: id,
    diff: { before },
    ip_address: context.ip_address || context.ip
  }).catch(() => {});
};

module.exports = { listEquipmentIncidentReports, getEquipmentIncidentReportById, createEquipmentIncidentReport, updateEquipmentIncidentReport, deleteEquipmentIncidentReport };
