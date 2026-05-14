const express = require('express');
const router = express.Router();
const equipmentWarrantyContractController = require('@controllers/equipment-warranty-contract/equipment-warranty-contract.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentWarrantyContractSchema, updateEquipmentWarrantyContractSchema, equipmentWarrantyContractIdParamsSchema, listEquipmentWarrantyContractsQuerySchema } = require('@validations/equipment-warranty-contract/equipment-warranty-contract.schema');

router.get('/', validateRequest({ query: listEquipmentWarrantyContractsQuerySchema }), authenticate(), equipmentWarrantyContractController.listEquipmentWarrantyContracts);
router.get('/:id', validateRequest({ params: equipmentWarrantyContractIdParamsSchema }), authenticate(), equipmentWarrantyContractController.getEquipmentWarrantyContractById);
router.post('/', validateRequest({ body: createEquipmentWarrantyContractSchema }), authenticate(), equipmentWarrantyContractController.createEquipmentWarrantyContract);
router.put('/:id', validateRequest({ params: equipmentWarrantyContractIdParamsSchema, body: updateEquipmentWarrantyContractSchema }), authenticate(), equipmentWarrantyContractController.updateEquipmentWarrantyContract);
router.delete('/:id', validateRequest({ params: equipmentWarrantyContractIdParamsSchema }), authenticate(), equipmentWarrantyContractController.deleteEquipmentWarrantyContract);

module.exports = router;

