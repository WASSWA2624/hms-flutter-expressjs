const express = require('express');
const router = express.Router();
const equipmentLocationHistoryController = require('@controllers/equipment-location-history/equipment-location-history.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentLocationHistorySchema, updateEquipmentLocationHistorySchema, equipmentLocationHistoryIdParamsSchema, listEquipmentLocationHistorysQuerySchema } = require('@validations/equipment-location-history/equipment-location-history.schema');

router.get('/', validateRequest({ query: listEquipmentLocationHistorysQuerySchema }), authenticate(), equipmentLocationHistoryController.listEquipmentLocationHistorys);
router.get('/:id', validateRequest({ params: equipmentLocationHistoryIdParamsSchema }), authenticate(), equipmentLocationHistoryController.getEquipmentLocationHistoryById);
router.post('/', validateRequest({ body: createEquipmentLocationHistorySchema }), authenticate(), equipmentLocationHistoryController.createEquipmentLocationHistory);
router.put('/:id', validateRequest({ params: equipmentLocationHistoryIdParamsSchema, body: updateEquipmentLocationHistorySchema }), authenticate(), equipmentLocationHistoryController.updateEquipmentLocationHistory);
router.delete('/:id', validateRequest({ params: equipmentLocationHistoryIdParamsSchema }), authenticate(), equipmentLocationHistoryController.deleteEquipmentLocationHistory);

module.exports = router;

