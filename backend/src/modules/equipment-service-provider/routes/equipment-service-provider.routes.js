const express = require('express');
const router = express.Router();
const equipmentServiceProviderController = require('@controllers/equipment-service-provider/equipment-service-provider.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentServiceProviderSchema, updateEquipmentServiceProviderSchema, equipmentServiceProviderIdParamsSchema, listEquipmentServiceProvidersQuerySchema } = require('@validations/equipment-service-provider/equipment-service-provider.schema');

router.get('/', validateRequest({ query: listEquipmentServiceProvidersQuerySchema }), authenticate(), equipmentServiceProviderController.listEquipmentServiceProviders);
router.get('/:id', validateRequest({ params: equipmentServiceProviderIdParamsSchema }), authenticate(), equipmentServiceProviderController.getEquipmentServiceProviderById);
router.post('/', validateRequest({ body: createEquipmentServiceProviderSchema }), authenticate(), equipmentServiceProviderController.createEquipmentServiceProvider);
router.put('/:id', validateRequest({ params: equipmentServiceProviderIdParamsSchema, body: updateEquipmentServiceProviderSchema }), authenticate(), equipmentServiceProviderController.updateEquipmentServiceProvider);
router.delete('/:id', validateRequest({ params: equipmentServiceProviderIdParamsSchema }), authenticate(), equipmentServiceProviderController.deleteEquipmentServiceProvider);

module.exports = router;

