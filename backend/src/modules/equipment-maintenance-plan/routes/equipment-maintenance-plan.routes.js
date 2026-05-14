const express = require('express');
const router = express.Router();
const equipmentMaintenancePlanController = require('@controllers/equipment-maintenance-plan/equipment-maintenance-plan.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentMaintenancePlanSchema, updateEquipmentMaintenancePlanSchema, equipmentMaintenancePlanIdParamsSchema, listEquipmentMaintenancePlansQuerySchema } = require('@validations/equipment-maintenance-plan/equipment-maintenance-plan.schema');

router.get('/', validateRequest({ query: listEquipmentMaintenancePlansQuerySchema }), authenticate(), equipmentMaintenancePlanController.listEquipmentMaintenancePlans);
router.get('/:id', validateRequest({ params: equipmentMaintenancePlanIdParamsSchema }), authenticate(), equipmentMaintenancePlanController.getEquipmentMaintenancePlanById);
router.post('/', validateRequest({ body: createEquipmentMaintenancePlanSchema }), authenticate(), equipmentMaintenancePlanController.createEquipmentMaintenancePlan);
router.put('/:id', validateRequest({ params: equipmentMaintenancePlanIdParamsSchema, body: updateEquipmentMaintenancePlanSchema }), authenticate(), equipmentMaintenancePlanController.updateEquipmentMaintenancePlan);
router.delete('/:id', validateRequest({ params: equipmentMaintenancePlanIdParamsSchema }), authenticate(), equipmentMaintenancePlanController.deleteEquipmentMaintenancePlan);

module.exports = router;

