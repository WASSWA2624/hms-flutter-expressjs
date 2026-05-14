const express = require('express');
const router = express.Router();
const equipmentCategoryController = require('@controllers/equipment-category/equipment-category.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentCategorySchema, updateEquipmentCategorySchema, equipmentCategoryIdParamsSchema, listEquipmentCategorysQuerySchema } = require('@validations/equipment-category/equipment-category.schema');

router.get('/', validateRequest({ query: listEquipmentCategorysQuerySchema }), authenticate(), equipmentCategoryController.listEquipmentCategorys);
router.get('/:id', validateRequest({ params: equipmentCategoryIdParamsSchema }), authenticate(), equipmentCategoryController.getEquipmentCategoryById);
router.post('/', validateRequest({ body: createEquipmentCategorySchema }), authenticate(), equipmentCategoryController.createEquipmentCategory);
router.put('/:id', validateRequest({ params: equipmentCategoryIdParamsSchema, body: updateEquipmentCategorySchema }), authenticate(), equipmentCategoryController.updateEquipmentCategory);
router.delete('/:id', validateRequest({ params: equipmentCategoryIdParamsSchema }), authenticate(), equipmentCategoryController.deleteEquipmentCategory);

module.exports = router;

