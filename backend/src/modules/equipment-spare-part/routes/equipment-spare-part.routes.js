const express = require('express');
const router = express.Router();
const equipmentSparePartController = require('@controllers/equipment-spare-part/equipment-spare-part.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentSparePartSchema, updateEquipmentSparePartSchema, equipmentSparePartIdParamsSchema, listEquipmentSparePartsQuerySchema } = require('@validations/equipment-spare-part/equipment-spare-part.schema');

router.get('/', validateRequest({ query: listEquipmentSparePartsQuerySchema }), authenticate(), equipmentSparePartController.listEquipmentSpareParts);
router.get('/:id', validateRequest({ params: equipmentSparePartIdParamsSchema }), authenticate(), equipmentSparePartController.getEquipmentSparePartById);
router.post('/', validateRequest({ body: createEquipmentSparePartSchema }), authenticate(), equipmentSparePartController.createEquipmentSparePart);
router.put('/:id', validateRequest({ params: equipmentSparePartIdParamsSchema, body: updateEquipmentSparePartSchema }), authenticate(), equipmentSparePartController.updateEquipmentSparePart);
router.delete('/:id', validateRequest({ params: equipmentSparePartIdParamsSchema }), authenticate(), equipmentSparePartController.deleteEquipmentSparePart);

module.exports = router;

