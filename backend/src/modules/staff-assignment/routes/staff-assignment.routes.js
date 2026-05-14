const express = require('express');
const router = express.Router();
const staffAssignmentController = require('@controllers/staff-assignment/staff-assignment.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createStaffAssignmentSchema,
  updateStaffAssignmentSchema,
  staffAssignmentIdParamsSchema,
  listStaffAssignmentsQuerySchema,
} = require('@validations/staff-assignment/staff-assignment.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listStaffAssignmentsQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffAssignmentController.listStaffAssignments);
router.get('/:id', validateRequest({ params: staffAssignmentIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffAssignmentController.getStaffAssignmentById);
router.post('/', validateRequest({ body: createStaffAssignmentSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffAssignmentController.createStaffAssignment);
router.put('/:id', validateRequest({ params: staffAssignmentIdParamsSchema, body: updateStaffAssignmentSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffAssignmentController.updateStaffAssignment);
router.delete('/:id', validateRequest({ params: staffAssignmentIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffAssignmentController.deleteStaffAssignment);

module.exports = router;
