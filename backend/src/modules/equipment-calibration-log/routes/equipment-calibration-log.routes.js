const express = require('express');
const router = express.Router();
const equipmentCalibrationLogController = require('@controllers/equipment-calibration-log/equipment-calibration-log.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentCalibrationLogSchema, updateEquipmentCalibrationLogSchema, equipmentCalibrationLogIdParamsSchema, listEquipmentCalibrationLogsQuerySchema } = require('@validations/equipment-calibration-log/equipment-calibration-log.schema');

router.get('/', validateRequest({ query: listEquipmentCalibrationLogsQuerySchema }), authenticate(), equipmentCalibrationLogController.listEquipmentCalibrationLogs);
router.get('/:id', validateRequest({ params: equipmentCalibrationLogIdParamsSchema }), authenticate(), equipmentCalibrationLogController.getEquipmentCalibrationLogById);
router.post('/', validateRequest({ body: createEquipmentCalibrationLogSchema }), authenticate(), equipmentCalibrationLogController.createEquipmentCalibrationLog);
router.put('/:id', validateRequest({ params: equipmentCalibrationLogIdParamsSchema, body: updateEquipmentCalibrationLogSchema }), authenticate(), equipmentCalibrationLogController.updateEquipmentCalibrationLog);
router.delete('/:id', validateRequest({ params: equipmentCalibrationLogIdParamsSchema }), authenticate(), equipmentCalibrationLogController.deleteEquipmentCalibrationLog);

module.exports = router;

