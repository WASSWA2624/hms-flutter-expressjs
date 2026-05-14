const express = require('express');
const router = express.Router();
const equipmentDowntimeLogController = require('@controllers/equipment-downtime-log/equipment-downtime-log.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentDowntimeLogSchema, updateEquipmentDowntimeLogSchema, equipmentDowntimeLogIdParamsSchema, listEquipmentDowntimeLogsQuerySchema } = require('@validations/equipment-downtime-log/equipment-downtime-log.schema');

router.get('/', validateRequest({ query: listEquipmentDowntimeLogsQuerySchema }), authenticate(), equipmentDowntimeLogController.listEquipmentDowntimeLogs);
router.get('/:id', validateRequest({ params: equipmentDowntimeLogIdParamsSchema }), authenticate(), equipmentDowntimeLogController.getEquipmentDowntimeLogById);
router.post('/', validateRequest({ body: createEquipmentDowntimeLogSchema }), authenticate(), equipmentDowntimeLogController.createEquipmentDowntimeLog);
router.put('/:id', validateRequest({ params: equipmentDowntimeLogIdParamsSchema, body: updateEquipmentDowntimeLogSchema }), authenticate(), equipmentDowntimeLogController.updateEquipmentDowntimeLog);
router.delete('/:id', validateRequest({ params: equipmentDowntimeLogIdParamsSchema }), authenticate(), equipmentDowntimeLogController.deleteEquipmentDowntimeLog);

module.exports = router;

