/**
 * Staff availability routes
 */
const express = require('express');
const router = express.Router();
const staffAvailabilityController = require('@controllers/staff-availability/staff-availability.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createStaffAvailabilitySchema,
  updateStaffAvailabilitySchema,
  staffAvailabilityIdParamsSchema,
  listStaffAvailabilitiesQuerySchema
} = require('@validations/staff-availability/staff-availability.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listStaffAvailabilitiesQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffAvailabilityController.list);
router.get('/:id', validateRequest({ params: staffAvailabilityIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffAvailabilityController.getById);
router.post('/', validateRequest({ body: createStaffAvailabilitySchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffAvailabilityController.create);
router.put('/:id', validateRequest({ params: staffAvailabilityIdParamsSchema, body: updateStaffAvailabilitySchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffAvailabilityController.update);
router.delete('/:id', validateRequest({ params: staffAvailabilityIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffAvailabilityController.remove);

module.exports = router;

