const express = require('express');
const router = express.Router();
const staffProfileController = require('@controllers/staff-profile/staff-profile.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createStaffProfileSchema,
  updateStaffProfileSchema,
  staffProfileIdParamsSchema,
  listStaffProfilesQuerySchema,
} = require('@validations/staff-profile/staff-profile.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listStaffProfilesQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffProfileController.listStaffProfiles);
router.get('/:id', validateRequest({ params: staffProfileIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffProfileController.getStaffProfileById);
router.post('/', validateRequest({ body: createStaffProfileSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffProfileController.createStaffProfile);
router.put('/:id', validateRequest({ params: staffProfileIdParamsSchema, body: updateStaffProfileSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffProfileController.updateStaffProfile);
router.delete('/:id', validateRequest({ params: staffProfileIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffProfileController.deleteStaffProfile);

module.exports = router;
