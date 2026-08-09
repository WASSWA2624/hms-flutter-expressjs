const express = require('express');
const router = express.Router();
const rosterController = require('@controllers/roster/roster.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createRosterSchema,
  updateRosterSchema,
  publishRosterSchema,
  generateRosterSchema,
  rosterIdParamsSchema,
  rosterStaffParamsSchema,
  attachRosterStaffSchema,
  listRostersQuerySchema} = require('@validations/roster/roster.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listRostersQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), rosterController.listRosters);
router.get('/:id', validateRequest({ params: rosterIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), rosterController.getRosterById);
router.post('/', validateRequest({ body: createRosterSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterController.createRoster);
router.put('/:id', validateRequest({ params: rosterIdParamsSchema, body: updateRosterSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterController.updateRoster);
router.delete('/:id', validateRequest({ params: rosterIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterController.deleteRoster);
router.post('/:id/publish', validateRequest({ params: rosterIdParamsSchema, body: publishRosterSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterController.publishRoster);
router.post('/:id/generate', validateRequest({ params: rosterIdParamsSchema, body: generateRosterSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterController.generateRoster);
router.post('/:id/staff', validateRequest({ params: rosterIdParamsSchema, body: attachRosterStaffSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterController.attachRosterStaff);
router.delete('/:id/staff/:staffProfileId', validateRequest({ params: rosterStaffParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterController.detachRosterStaff);

module.exports = router;
