const express = require('express');
const router = express.Router();
const payrollItemController = require('@controllers/payroll-item/payroll-item.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPayrollItemSchema,
  updatePayrollItemSchema,
  payrollItemIdParamsSchema,
  listPayrollItemsQuerySchema,
} = require('@validations/payroll-item/payroll-item.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listPayrollItemsQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), payrollItemController.listPayrollItems);
router.get('/:id', validateRequest({ params: payrollItemIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), payrollItemController.getPayrollItemById);
router.post('/', validateRequest({ body: createPayrollItemSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), payrollItemController.createPayrollItem);
router.put('/:id', validateRequest({ params: payrollItemIdParamsSchema, body: updatePayrollItemSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), payrollItemController.updatePayrollItem);
router.delete('/:id', validateRequest({ params: payrollItemIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), payrollItemController.deletePayrollItem);

module.exports = router;
