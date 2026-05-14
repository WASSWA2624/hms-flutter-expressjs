const express = require('express');
const router = express.Router();
const nurseRosterController = require('@controllers/nurse-roster/nurse-roster.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createNurseRosterSchema,
  updateNurseRosterSchema,
  publishNurseRosterSchema,
  generateNurseRosterSchema,
  nurseRosterIdParamsSchema,
  listNurseRostersQuerySchema,
} = require('@validations/nurse-roster/nurse-roster.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listNurseRostersQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), nurseRosterController.listNurseRosters);
router.get('/:id', validateRequest({ params: nurseRosterIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), nurseRosterController.getNurseRosterById);
router.post('/', validateRequest({ body: createNurseRosterSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), nurseRosterController.createNurseRoster);
router.put('/:id', validateRequest({ params: nurseRosterIdParamsSchema, body: updateNurseRosterSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), nurseRosterController.updateNurseRoster);
router.delete('/:id', validateRequest({ params: nurseRosterIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), nurseRosterController.deleteNurseRoster);
router.post('/:id/publish', validateRequest({ params: nurseRosterIdParamsSchema, body: publishNurseRosterSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), nurseRosterController.publishNurseRoster);
router.post('/:id/generate', validateRequest({ params: nurseRosterIdParamsSchema, body: generateNurseRosterSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), nurseRosterController.generateNurseRoster);

module.exports = router;
