const express = require('express');
const router = express.Router();
const equipmentDisposalTransferController = require('@controllers/equipment-disposal-transfer/equipment-disposal-transfer.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentDisposalTransferSchema, updateEquipmentDisposalTransferSchema, equipmentDisposalTransferIdParamsSchema, listEquipmentDisposalTransfersQuerySchema } = require('@validations/equipment-disposal-transfer/equipment-disposal-transfer.schema');

router.get('/', validateRequest({ query: listEquipmentDisposalTransfersQuerySchema }), authenticate(), equipmentDisposalTransferController.listEquipmentDisposalTransfers);
router.get('/:id', validateRequest({ params: equipmentDisposalTransferIdParamsSchema }), authenticate(), equipmentDisposalTransferController.getEquipmentDisposalTransferById);
router.post('/', validateRequest({ body: createEquipmentDisposalTransferSchema }), authenticate(), equipmentDisposalTransferController.createEquipmentDisposalTransfer);
router.put('/:id', validateRequest({ params: equipmentDisposalTransferIdParamsSchema, body: updateEquipmentDisposalTransferSchema }), authenticate(), equipmentDisposalTransferController.updateEquipmentDisposalTransfer);
router.delete('/:id', validateRequest({ params: equipmentDisposalTransferIdParamsSchema }), authenticate(), equipmentDisposalTransferController.deleteEquipmentDisposalTransfer);

module.exports = router;

