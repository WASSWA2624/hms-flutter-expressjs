const express = require('express');
const router = express.Router();
const equipmentWorkOrderController = require('@controllers/equipment-work-order/equipment-work-order.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createEquipmentWorkOrderSchema,
  updateEquipmentWorkOrderSchema,
  startEquipmentWorkOrderSchema,
  returnToServiceEquipmentWorkOrderSchema,
  equipmentWorkOrderIdParamsSchema,
  listEquipmentWorkOrdersQuerySchema
} = require('@validations/equipment-work-order/equipment-work-order.schema');

router.get('/', validateRequest({ query: listEquipmentWorkOrdersQuerySchema }), authenticate(), equipmentWorkOrderController.listEquipmentWorkOrders);
router.get('/:id', validateRequest({ params: equipmentWorkOrderIdParamsSchema }), authenticate(), equipmentWorkOrderController.getEquipmentWorkOrderById);
router.post('/', validateRequest({ body: createEquipmentWorkOrderSchema }), authenticate(), equipmentWorkOrderController.createEquipmentWorkOrder);
router.put('/:id', validateRequest({ params: equipmentWorkOrderIdParamsSchema, body: updateEquipmentWorkOrderSchema }), authenticate(), equipmentWorkOrderController.updateEquipmentWorkOrder);
router.delete('/:id', validateRequest({ params: equipmentWorkOrderIdParamsSchema }), authenticate(), equipmentWorkOrderController.deleteEquipmentWorkOrder);
router.post('/:id/start', validateRequest({ params: equipmentWorkOrderIdParamsSchema, body: startEquipmentWorkOrderSchema }), authenticate(), equipmentWorkOrderController.startEquipmentWorkOrder);
router.post('/:id/return-to-service', validateRequest({ params: equipmentWorkOrderIdParamsSchema, body: returnToServiceEquipmentWorkOrderSchema }), authenticate(), equipmentWorkOrderController.returnToServiceEquipmentWorkOrder);

module.exports = router;
