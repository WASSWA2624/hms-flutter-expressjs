const express = require('express');
const router = express.Router();
const staffLeaveController = require('@controllers/staff-leave/staff-leave.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createStaffLeaveSchema,
  updateStaffLeaveSchema,
  staffLeaveIdParamsSchema,
  listStaffLeavesQuerySchema,
} = require('@validations/staff-leave/staff-leave.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listStaffLeavesQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffLeaveController.listStaffLeaves);
router.get('/:id', validateRequest({ params: staffLeaveIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffLeaveController.getStaffLeaveById);
router.post('/', validateRequest({ body: createStaffLeaveSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffLeaveController.createStaffLeave);
router.put('/:id', validateRequest({ params: staffLeaveIdParamsSchema, body: updateStaffLeaveSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffLeaveController.updateStaffLeave);
router.delete('/:id', validateRequest({ params: staffLeaveIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffLeaveController.deleteStaffLeave);

module.exports = router;
