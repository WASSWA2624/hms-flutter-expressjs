const express = require('express');
const router = express.Router();
const shiftAssignmentController = require('@controllers/shift-assignment/shift-assignment.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createShiftAssignmentSchema,
  updateShiftAssignmentSchema,
  shiftAssignmentIdParamsSchema,
  listShiftAssignmentsQuerySchema,
  listMyShiftAssignmentsQuerySchema} = require('@validations/shift-assignment/shift-assignment.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];
const PROFILE_READ_SCOPES = [PERMISSIONS.PROFILE_READ];

router.get(
  '/me',
  validateRequest({ query: listMyShiftAssignmentsQuerySchema }),
  authenticate(),
  authorize(PROFILE_READ_SCOPES, 'permission'),
  shiftAssignmentController.listMyShiftAssignments
);

router.get('/', validateRequest({ query: listShiftAssignmentsQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), shiftAssignmentController.listShiftAssignments);
router.get('/:id', validateRequest({ params: shiftAssignmentIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), shiftAssignmentController.getShiftAssignmentById);
router.post('/', validateRequest({ body: createShiftAssignmentSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftAssignmentController.createShiftAssignment);
router.put('/:id', validateRequest({ params: shiftAssignmentIdParamsSchema, body: updateShiftAssignmentSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftAssignmentController.updateShiftAssignment);
router.delete('/:id', validateRequest({ params: shiftAssignmentIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), shiftAssignmentController.deleteShiftAssignment);

module.exports = router;
