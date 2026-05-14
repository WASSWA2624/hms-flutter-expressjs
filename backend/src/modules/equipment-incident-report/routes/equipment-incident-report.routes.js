const express = require('express');
const router = express.Router();
const equipmentIncidentReportController = require('@controllers/equipment-incident-report/equipment-incident-report.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentIncidentReportSchema, updateEquipmentIncidentReportSchema, equipmentIncidentReportIdParamsSchema, listEquipmentIncidentReportsQuerySchema } = require('@validations/equipment-incident-report/equipment-incident-report.schema');

router.get('/', validateRequest({ query: listEquipmentIncidentReportsQuerySchema }), authenticate(), equipmentIncidentReportController.listEquipmentIncidentReports);
router.get('/:id', validateRequest({ params: equipmentIncidentReportIdParamsSchema }), authenticate(), equipmentIncidentReportController.getEquipmentIncidentReportById);
router.post('/', validateRequest({ body: createEquipmentIncidentReportSchema }), authenticate(), equipmentIncidentReportController.createEquipmentIncidentReport);
router.put('/:id', validateRequest({ params: equipmentIncidentReportIdParamsSchema, body: updateEquipmentIncidentReportSchema }), authenticate(), equipmentIncidentReportController.updateEquipmentIncidentReport);
router.delete('/:id', validateRequest({ params: equipmentIncidentReportIdParamsSchema }), authenticate(), equipmentIncidentReportController.deleteEquipmentIncidentReport);

module.exports = router;

