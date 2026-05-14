const express = require('express');
const router = express.Router();
const equipmentSafetyTestLogController = require('@controllers/equipment-safety-test-log/equipment-safety-test-log.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentSafetyTestLogSchema, updateEquipmentSafetyTestLogSchema, equipmentSafetyTestLogIdParamsSchema, listEquipmentSafetyTestLogsQuerySchema } = require('@validations/equipment-safety-test-log/equipment-safety-test-log.schema');

router.get('/', validateRequest({ query: listEquipmentSafetyTestLogsQuerySchema }), authenticate(), equipmentSafetyTestLogController.listEquipmentSafetyTestLogs);
router.get('/:id', validateRequest({ params: equipmentSafetyTestLogIdParamsSchema }), authenticate(), equipmentSafetyTestLogController.getEquipmentSafetyTestLogById);
router.post('/', validateRequest({ body: createEquipmentSafetyTestLogSchema }), authenticate(), equipmentSafetyTestLogController.createEquipmentSafetyTestLog);
router.put('/:id', validateRequest({ params: equipmentSafetyTestLogIdParamsSchema, body: updateEquipmentSafetyTestLogSchema }), authenticate(), equipmentSafetyTestLogController.updateEquipmentSafetyTestLog);
router.delete('/:id', validateRequest({ params: equipmentSafetyTestLogIdParamsSchema }), authenticate(), equipmentSafetyTestLogController.deleteEquipmentSafetyTestLog);

module.exports = router;

