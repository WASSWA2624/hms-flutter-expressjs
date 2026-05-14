/**
 * Shift template routes
 */
const express = require('express');
const router = express.Router();
const shiftTemplateController = require('@controllers/shift-template/shift-template.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createShiftTemplateSchema,
  updateShiftTemplateSchema,
  shiftTemplateIdParamsSchema,
  listShiftTemplatesQuerySchema
} = require('@validations/shift-template/shift-template.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listShiftTemplatesQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), shiftTemplateController.list);
router.get('/:id', validateRequest({ params: shiftTemplateIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), shiftTemplateController.getById);
router.post('/', validateRequest({ body: createShiftTemplateSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftTemplateController.create);
router.put('/:id', validateRequest({ params: shiftTemplateIdParamsSchema, body: updateShiftTemplateSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftTemplateController.update);
router.delete('/:id', validateRequest({ params: shiftTemplateIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftTemplateController.remove);

module.exports = router;

