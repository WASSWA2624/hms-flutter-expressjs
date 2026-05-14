const express = require('express');
const router = express.Router();
const shiftController = require('@controllers/shift/shift.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createShiftSchema,
  updateShiftSchema,
  publishShiftSchema,
  shiftIdParamsSchema,
  listShiftsQuerySchema,
} = require('@validations/shift/shift.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listShiftsQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), shiftController.listShifts);
router.get('/:id', validateRequest({ params: shiftIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), shiftController.getShiftById);
router.post('/', validateRequest({ body: createShiftSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftController.createShift);
router.put('/:id', validateRequest({ params: shiftIdParamsSchema, body: updateShiftSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftController.updateShift);
router.delete('/:id', validateRequest({ params: shiftIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftController.deleteShift);
router.post('/:id/publish', validateRequest({ params: shiftIdParamsSchema, body: publishShiftSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftController.publishShift);

module.exports = router;
