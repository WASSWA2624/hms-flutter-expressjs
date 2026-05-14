const express = require('express');
const router = express.Router();
const equipmentUtilizationSnapshotController = require('@controllers/equipment-utilization-snapshot/equipment-utilization-snapshot.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentUtilizationSnapshotSchema, updateEquipmentUtilizationSnapshotSchema, equipmentUtilizationSnapshotIdParamsSchema, listEquipmentUtilizationSnapshotsQuerySchema } = require('@validations/equipment-utilization-snapshot/equipment-utilization-snapshot.schema');

router.get('/', validateRequest({ query: listEquipmentUtilizationSnapshotsQuerySchema }), authenticate(), equipmentUtilizationSnapshotController.listEquipmentUtilizationSnapshots);
router.get('/:id', validateRequest({ params: equipmentUtilizationSnapshotIdParamsSchema }), authenticate(), equipmentUtilizationSnapshotController.getEquipmentUtilizationSnapshotById);
router.post('/', validateRequest({ body: createEquipmentUtilizationSnapshotSchema }), authenticate(), equipmentUtilizationSnapshotController.createEquipmentUtilizationSnapshot);
router.put('/:id', validateRequest({ params: equipmentUtilizationSnapshotIdParamsSchema, body: updateEquipmentUtilizationSnapshotSchema }), authenticate(), equipmentUtilizationSnapshotController.updateEquipmentUtilizationSnapshot);
router.delete('/:id', validateRequest({ params: equipmentUtilizationSnapshotIdParamsSchema }), authenticate(), equipmentUtilizationSnapshotController.deleteEquipmentUtilizationSnapshot);

module.exports = router;

