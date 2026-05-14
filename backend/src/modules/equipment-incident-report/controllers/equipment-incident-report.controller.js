const equipmentIncidentReportService = require('@services/equipment-incident-report/equipment-incident-report.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentIncidentReports = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentIncidentReportService.listEquipmentIncidentReports(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_incident_report.list.success', result.equipmentIncidentReports, result.pagination);
});

const getEquipmentIncidentReportById = asyncHandler(async (req, res) => {
  const item = await equipmentIncidentReportService.getEquipmentIncidentReportById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_incident_report.get.success', item);
});

const createEquipmentIncidentReport = asyncHandler(async (req, res) => {
  const item = await equipmentIncidentReportService.createEquipmentIncidentReport(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_incident_report.create.success', item);
});

const updateEquipmentIncidentReport = asyncHandler(async (req, res) => {
  const item = await equipmentIncidentReportService.updateEquipmentIncidentReport(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_incident_report.update.success', item);
});

const deleteEquipmentIncidentReport = asyncHandler(async (req, res) => {
  await equipmentIncidentReportService.deleteEquipmentIncidentReport(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentIncidentReports, getEquipmentIncidentReportById, createEquipmentIncidentReport, updateEquipmentIncidentReport, deleteEquipmentIncidentReport };
