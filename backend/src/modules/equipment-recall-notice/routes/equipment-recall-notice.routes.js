const express = require('express');
const router = express.Router();
const equipmentRecallNoticeController = require('@controllers/equipment-recall-notice/equipment-recall-notice.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const { createEquipmentRecallNoticeSchema, updateEquipmentRecallNoticeSchema, equipmentRecallNoticeIdParamsSchema, listEquipmentRecallNoticesQuerySchema } = require('@validations/equipment-recall-notice/equipment-recall-notice.schema');

router.get('/', validateRequest({ query: listEquipmentRecallNoticesQuerySchema }), authenticate(), equipmentRecallNoticeController.listEquipmentRecallNotices);
router.get('/:id', validateRequest({ params: equipmentRecallNoticeIdParamsSchema }), authenticate(), equipmentRecallNoticeController.getEquipmentRecallNoticeById);
router.post('/', validateRequest({ body: createEquipmentRecallNoticeSchema }), authenticate(), equipmentRecallNoticeController.createEquipmentRecallNotice);
router.put('/:id', validateRequest({ params: equipmentRecallNoticeIdParamsSchema, body: updateEquipmentRecallNoticeSchema }), authenticate(), equipmentRecallNoticeController.updateEquipmentRecallNotice);
router.delete('/:id', validateRequest({ params: equipmentRecallNoticeIdParamsSchema }), authenticate(), equipmentRecallNoticeController.deleteEquipmentRecallNotice);

module.exports = router;

