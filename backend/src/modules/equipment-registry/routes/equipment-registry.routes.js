const express = require('express');
const router = express.Router();
const equipmentRegistryController = require('@controllers/equipment-registry/equipment-registry.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentRegistrySchema, updateEquipmentRegistrySchema, equipmentRegistryIdParamsSchema, listEquipmentRegistrysQuerySchema } = require('@validations/equipment-registry/equipment-registry.schema');

router.get('/', validateRequest({ query: listEquipmentRegistrysQuerySchema }), authenticate(), equipmentRegistryController.listEquipmentRegistrys);
router.get('/:id', validateRequest({ params: equipmentRegistryIdParamsSchema }), authenticate(), equipmentRegistryController.getEquipmentRegistryById);
router.post('/', validateRequest({ body: createEquipmentRegistrySchema }), authenticate(), equipmentRegistryController.createEquipmentRegistry);
router.put('/:id', validateRequest({ params: equipmentRegistryIdParamsSchema, body: updateEquipmentRegistrySchema }), authenticate(), equipmentRegistryController.updateEquipmentRegistry);
router.delete('/:id', validateRequest({ params: equipmentRegistryIdParamsSchema }), authenticate(), equipmentRegistryController.deleteEquipmentRegistry);

module.exports = router;

