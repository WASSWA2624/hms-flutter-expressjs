const express = require('express');
const router = express.Router();
const payrollRunController = require('@controllers/payroll-run/payroll-run.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPayrollRunSchema,
  updatePayrollRunSchema,
  payrollRunIdParamsSchema,
  listPayrollRunsQuerySchema,
} = require('@validations/payroll-run/payroll-run.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listPayrollRunsQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), payrollRunController.listPayrollRuns);
router.get('/:id', validateRequest({ params: payrollRunIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), payrollRunController.getPayrollRunById);
router.post('/', validateRequest({ body: createPayrollRunSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), payrollRunController.createPayrollRun);
router.put('/:id', validateRequest({ params: payrollRunIdParamsSchema, body: updatePayrollRunSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), payrollRunController.updatePayrollRun);
router.delete('/:id', validateRequest({ params: payrollRunIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), payrollRunController.deletePayrollRun);

module.exports = router;
